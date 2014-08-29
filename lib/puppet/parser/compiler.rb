require 'forwardable'

require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/util/errors'

require 'puppet/resource/type_collection_helper'

# Maintain a graph of scopes, along with a bunch of data
# about the individual catalog we're compiling.
class Puppet::Parser::Compiler
  extend Forwardable

  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper
  include Puppet::Resource::TypeCollectionHelper

  def self.compile(node)
    $env_module_directories = nil
    node.environment.check_for_reparse

    if node.environment.conflicting_manifest_settings?
      errmsg = [
        "The 'disable_per_environment_manifest' setting is true, and this '#{node.environment}'",
        "has an environment.conf manifest that conflicts with the 'default_manifest' setting.",
        "Compilation has been halted in order to avoid running a catalog which may be using",
        "unexpected manifests. For more information, see",
        "http://docs.puppetlabs.com/puppet/latest/reference/environments.html",
      ]
      raise(Puppet::Error, errmsg.join(' '))
    end

    new(node).compile.to_resource
  rescue => detail
    message = "#{detail} on node #{node.name}"
    Puppet.log_exception(detail, message)
    raise Puppet::Error, message, detail.backtrace
 end

  attr_reader :node, :facts, :collections, :catalog, :resources, :relationships, :topscope

  # The injector that provides lookup services, or nil if accessed before the compiler has started compiling and
  # bootstrapped. The injector is initialized and available before any manifests are evaluated.
  #
  # @return [Puppet::Pops::Binder::Injector, nil] The injector that provides lookup services for this compiler/environment
  # @api public
  #
  attr_accessor :injector

  # Access to the configured loaders for 4x
  # @return [Puppet::Pops::Loader::Loaders] the configured loaders
  # @api private
  attr_reader :loaders

  # The injector that provides lookup services during the creation of the {#injector}.
  # @return [Puppet::Pops::Binder::Injector, nil] The injector that provides lookup services during injector creation
  #   for this compiler/environment
  #
  # @api private
  #
  attr_accessor :boot_injector

  # Add a collection to the global list.
  def_delegator :@collections,   :<<, :add_collection
  def_delegator :@relationships, :<<, :add_relationship

  # Store a resource override.
  def add_override(override)
    # If possible, merge the override in immediately.
    if resource = @catalog.resource(override.ref)
      resource.merge(override)
    else
      # Otherwise, store the override for later; these
      # get evaluated in Resource#finish.
      @resource_overrides[override.ref] << override
    end
  end

  def add_resource(scope, resource)
    @resources << resource

    # Note that this will fail if the resource is not unique.
    @catalog.add_resource(resource)

    if not resource.class? and resource[:stage]
      raise ArgumentError, "Only classes can set 'stage'; normal resources like #{resource} cannot change run stage"
    end

    # Stages should not be inside of classes.  They are always a
    # top-level container, regardless of where they appear in the
    # manifest.
    return if resource.stage?

    # This adds a resource to the class it lexically appears in in the
    # manifest.
    unless resource.class?
      return @catalog.add_edge(scope.resource, resource)
    end
  end

  # Do we use nodes found in the code, vs. the external node sources?
  def_delegator :known_resource_types, :nodes?, :ast_nodes?

  # Store the fact that we've evaluated a class
  def add_class(name)
    @catalog.add_class(name) unless name == ""
  end


  # Return a list of all of the defined classes.
  def_delegator :@catalog, :classes, :classlist

  # Compiler our catalog.  This mostly revolves around finding and evaluating classes.
  # This is the main entry into our catalog.
  def compile
    Puppet.override( @context_overrides , "For compiling #{node.name}") do
      @catalog.environment_instance = environment

      # Set the client's parameters into the top scope.
      Puppet::Util::Profiler.profile("Compile: Set node parameters", [:compiler, :set_node_params]) { set_node_parameters }

      Puppet::Util::Profiler.profile("Compile: Created settings scope", [:compiler, :create_settings_scope]) { create_settings_scope }

      if is_binder_active?
        # create injector, if not already created - this is for 3x that does not trigger
        # lazy loading of injector via context
        Puppet::Util::Profiler.profile("Compile: Created injector", [:compiler, :create_injector]) { injector }
      end

      Puppet::Util::Profiler.profile("Compile: Evaluated main", [:compiler, :evaluate_main]) { evaluate_main }

      Puppet::Util::Profiler.profile("Compile: Evaluated AST node", [:compiler, :evaluate_ast_node]) { evaluate_ast_node }

      Puppet::Util::Profiler.profile("Compile: Evaluated node classes", [:compiler, :evaluate_node_classes]) { evaluate_node_classes }

      Puppet::Util::Profiler.profile("Compile: Evaluated generators", [:compiler, :evaluate_generators]) { evaluate_generators }

      Puppet::Util::Profiler.profile("Compile: Finished catalog", [:compiler, :finish_catalog]) { finish }

      fail_on_unevaluated

      @catalog
    end
  end

  # Constructs the overrides for the context
  def context_overrides()
    if Puppet[:parser] == 'future'
      require 'puppet/loaders'
      {
        :current_environment => environment,
        :global_scope => @topscope,             # 4x placeholder for new global scope
        :loaders  => lambda {|| loaders() },    # 4x loaders
        :injector => lambda {|| injector() }    # 4x API - via context instead of via compiler
      }
    else
      {
        :current_environment => environment,
      }
    end
  end

  def_delegator :@collections, :delete, :delete_collection

  # Return the node's environment.
  def environment
    node.environment
  end

  # Evaluate all of the classes specified by the node.
  # Classes with parameters are evaluated as if they were declared.
  # Classes without parameters or with an empty set of parameters are evaluated
  # as if they were included. This means classes with an empty set of
  # parameters won't conflict even if the class has already been included.
  def evaluate_node_classes
    if @node.classes.is_a? Hash
      classes_with_params, classes_without_params = @node.classes.partition {|name,params| params and !params.empty?}

      # The results from Hash#partition are arrays of pairs rather than hashes,
      # so we have to convert to the forms evaluate_classes expects (Hash, and
      # Array of class names)
      classes_with_params = Hash[classes_with_params]
      classes_without_params.map!(&:first)
    else
      classes_with_params = {}
      classes_without_params = @node.classes
    end

    evaluate_classes(classes_without_params, @node_scope || topscope)

    evaluate_classes(classes_with_params, @node_scope || topscope)
  end

  # Evaluate each specified class in turn.  If there are any classes we can't
  # find, raise an error.  This method really just creates resource objects
  # that point back to the classes, and then the resources are themselves
  # evaluated later in the process.
  #
  # Sometimes we evaluate classes with a fully qualified name already, in which
  # case, we tell scope.find_hostclass we've pre-qualified the name so it
  # doesn't need to search its namespaces again.  This gets around a weird
  # edge case of duplicate class names, one at top scope and one nested in our
  # namespace and the wrong one (or both!) getting selected. See ticket #13349
  # for more detail.  --jeffweiss 26 apr 2012
  def evaluate_classes(classes, scope, lazy_evaluate = true, fqname = false)
    raise Puppet::DevError, "No source for scope passed to evaluate_classes" unless scope.source
    class_parameters = nil
    # if we are a param class, save the classes hash
    # and transform classes to be the keys
    if classes.class == Hash
      class_parameters = classes
      classes = classes.keys
    end

    hostclasses = classes.collect do |name|
      scope.find_hostclass(name, :assume_fqname => fqname) or raise Puppet::Error, "Could not find class #{name} for #{node.name}"
    end

    if class_parameters
      resources = ensure_classes_with_parameters(scope, hostclasses, class_parameters)
      if !lazy_evaluate
        resources.each(&:evaluate)
      end

      resources
    else
      already_included, newly_included = ensure_classes_without_parameters(scope, hostclasses)
      if !lazy_evaluate
        newly_included.each(&:evaluate)
      end

      already_included + newly_included
    end
  end

  def evaluate_relationships
    @relationships.each { |rel| rel.evaluate(catalog) }
  end

  # Return a resource by either its ref or its type and title.
  def_delegator :@catalog, :resource, :findresource

  def initialize(node, options = {})
    @node = node
    set_options(options)
    initvars
  end

  # Create a new scope, with either a specified parent scope or
  # using the top scope.
  def newscope(parent, options = {})
    parent ||= topscope
    scope = Puppet::Parser::Scope.new(self, options)
    scope.parent = parent
    scope
  end

  # Return any overrides for the given resource.
  def resource_overrides(resource)
    @resource_overrides[resource.ref]
  end

  def injector
    create_injector if @injector.nil?
    @injector
  end

  def loaders
    @loaders ||= Puppet::Pops::Loaders.new(environment)
  end

  def boot_injector
    create_boot_injector(nil) if @boot_injector.nil?
    @boot_injector
  end

  # Creates the boot injector from registered system, default, and injector config.
  # @return [Puppet::Pops::Binder::Injector] the created boot injector
  # @api private Cannot be 'private' since it is called from the BindingsComposer.
  #
  def create_boot_injector(env_boot_bindings)
    assert_binder_active()
    pb = Puppet::Pops::Binder
    boot_contribution = pb::SystemBindings.injector_boot_contribution(env_boot_bindings)
    final_contribution = pb::SystemBindings.final_contribution
    binder = pb::Binder.new(pb::BindingsFactory.layered_bindings(final_contribution, boot_contribution))
    @boot_injector = pb::Injector.new(binder)
  end

  # Answers if Puppet Binder should be active or not, and if it should and is not active, then it is activated.
  # @return [Boolean] true if the Puppet Binder should be activated
  def is_binder_active?
    should_be_active = Puppet[:binder] || Puppet[:parser] == 'future'
    if should_be_active
      # TODO: this should be in a central place, not just for ParserFactory anymore...
      Puppet::Parser::ParserFactory.assert_rgen_installed()
      @@binder_loaded ||= false
      unless @@binder_loaded
        require 'puppet/pops'
        require 'puppetx'
        @@binder_loaded = true
      end
    end
    should_be_active
  end

  private

  def ensure_classes_with_parameters(scope, hostclasses, parameters)
    hostclasses.collect do |klass|
      klass.ensure_in_catalog(scope, parameters[klass.name] || {})
    end
  end

  def ensure_classes_without_parameters(scope, hostclasses)
    already_included = []
    newly_included = []
    hostclasses.each do |klass|
      class_scope = scope.class_scope(klass)
      if class_scope
        already_included << class_scope.resource
      else
        newly_included << klass.ensure_in_catalog(scope)
      end
    end

    [already_included, newly_included]
  end

  # If ast nodes are enabled, then see if we can find and evaluate one.
  def evaluate_ast_node
    return unless ast_nodes?

    # Now see if we can find the node.
    astnode = nil
    @node.names.each do |name|
      break if astnode = known_resource_types.node(name.to_s.downcase)
    end

    unless (astnode ||= known_resource_types.node("default"))
      raise Puppet::ParseError, "Could not find default node or by name with '#{node.names.join(", ")}'"
    end

    # Create a resource to model this node, and then add it to the list
    # of resources.
    resource = astnode.ensure_in_catalog(topscope)

    resource.evaluate

    @node_scope = topscope.class_scope(astnode)
  end

  # Evaluate our collections and return true if anything returned an object.
  # The 'true' is used to continue a loop, so it's important.
  def evaluate_collections
    return false if @collections.empty?

    exceptwrap do
      # We have to iterate over a dup of the array because
      # collections can delete themselves from the list, which
      # changes its length and causes some collections to get missed.
      Puppet::Util::Profiler.profile("Evaluated collections", [:compiler, :evaluate_collections]) do
        found_something = false
        @collections.dup.each do |collection|
          found_something = true if collection.evaluate
        end
        found_something
      end
    end
  end

  # Make sure all of our resources have been evaluated into native resources.
  # We return true if any resources have, so that we know to continue the
  # evaluate_generators loop.
  def evaluate_definitions
    exceptwrap do
      Puppet::Util::Profiler.profile("Evaluated definitions", [:compiler, :evaluate_definitions]) do
        !unevaluated_resources.each do |resource|
          Puppet::Util::Profiler.profile("Evaluated resource #{resource}", [:compiler, :evaluate_resource, resource]) do
            resource.evaluate
          end
        end.empty?
      end
    end
  end

  # Iterate over collections and resources until we're sure that the whole
  # compile is evaluated.  This is necessary because both collections
  # and defined resources can generate new resources, which themselves could
  # be defined resources.
  def evaluate_generators
    count = 0
    loop do
      done = true

      Puppet::Util::Profiler.profile("Iterated (#{count + 1}) on generators", [:compiler, :iterate_on_generators]) do
        # Call collections first, then definitions.
        done = false if evaluate_collections
        done = false if evaluate_definitions
      end

      break if done

      count += 1

      if count > 1000
        raise Puppet::ParseError, "Somehow looped more than 1000 times while evaluating host catalog"
      end
    end
  end

  # Find and evaluate our main object, if possible.
  def evaluate_main
    @main = known_resource_types.find_hostclass([""], "") || known_resource_types.add(Puppet::Resource::Type.new(:hostclass, ""))
    @topscope.source = @main
    @main_resource = Puppet::Parser::Resource.new("class", :main, :scope => @topscope, :source => @main)
    @topscope.resource = @main_resource

    add_resource(@topscope, @main_resource)

    @main_resource.evaluate
  end

  # Make sure the entire catalog is evaluated.
  def fail_on_unevaluated
    fail_on_unevaluated_overrides
    fail_on_unevaluated_resource_collections
  end

  # If there are any resource overrides remaining, then we could
  # not find the resource they were supposed to override, so we
  # want to throw an exception.
  def fail_on_unevaluated_overrides
    remaining = @resource_overrides.values.flatten.collect(&:ref)

    if !remaining.empty?
      fail Puppet::ParseError,
        "Could not find resource(s) #{remaining.join(', ')} for overriding"
    end
  end

  # Make sure we don't have any remaining collections that specifically
  # look for resources, because we want to consider those to be
  # parse errors.
  def fail_on_unevaluated_resource_collections
    remaining = @collections.collect(&:resources).flatten.compact

    if !remaining.empty?
      raise Puppet::ParseError, "Failed to realize virtual resources #{remaining.join(', ')}"
    end
  end

  # Make sure all of our resources and such have done any last work
  # necessary.
  def finish
    evaluate_relationships

    resources.each do |resource|
      # Add in any resource overrides.
      if overrides = resource_overrides(resource)
        overrides.each do |over|
          resource.merge(over)
        end

        # Remove the overrides, so that the configuration knows there
        # are none left.
        overrides.clear
      end

      resource.finish if resource.respond_to?(:finish)
    end

    add_resource_metaparams
  end

  def add_resource_metaparams
    unless main = catalog.resource(:class, :main)
      raise "Couldn't find main"
    end

    names = Puppet::Type.metaparams.select do |name|
      !Puppet::Parser::Resource.relationship_parameter?(name)
    end

    data = {}
    catalog.walk(main, :out) do |source, target|
      if source_data = data[source] || metaparams_as_data(source, names)
        # only store anything in the data hash if we've actually got
        # data
        data[source] ||= source_data
        source_data.each do |param, value|
          target[param] = value if target[param].nil?
        end
        data[target] = source_data.merge(metaparams_as_data(target, names))
      end

      target.tag(*(source.tags))
    end
  end

  def metaparams_as_data(resource, params)
    data = nil
    params.each do |param|
      unless resource[param].nil?
        # Because we could be creating a hash for every resource,
        # and we actually probably don't often have any data here at all,
        # we're optimizing a bit by only creating a hash if there's
        # any data to put in it.
        data ||= {}
        data[param] = resource[param]
      end
    end
    data
  end

  # Set up all of our internal variables.
  def initvars
    # The list of overrides.  This is used to cache overrides on objects
    # that don't exist yet.  We store an array of each override.
    @resource_overrides = Hash.new do |overs, ref|
      overs[ref] = []
    end

    # The list of collections that have been created.  This is a global list,
    # but they each refer back to the scope that created them.
    @collections = []

    # The list of relationships to evaluate.
    @relationships = []

    # For maintaining the relationship between scopes and their resources.
    @catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment)

    # MOVED HERE - SCOPE IS NEEDED (MOVE-SCOPE)
    # Create the initial scope, it is needed early
    @topscope = Puppet::Parser::Scope.new(self)

    # Need to compute overrides here, and remember them, because we are about to
    # enter the magic zone of known_resource_types and intial import.
    # Expensive entries in the context are bound lazily.
    @context_overrides = context_overrides()

    # This construct ensures that initial import (triggered by instantiating
    # the structure 'known_resource_types') has a configured context
    # It cannot survive the initvars method, and is later reinstated
    # as part of compiling...
    #
    Puppet.override( @context_overrides , "For initializing compiler") do
      # THE MAGIC STARTS HERE ! This triggers parsing, loading etc.
      @catalog.version = known_resource_types.version
    end

    @catalog.add_resource(Puppet::Parser::Resource.new("stage", :main, :scope => @topscope))

    # local resource array to maintain resource ordering
    @resources = []

    # Make sure any external node classes are in our class list
    if @node.classes.class == Hash
      @catalog.add_class(*@node.classes.keys)
    else
      @catalog.add_class(*@node.classes)
    end
  end

  # Set the node's parameters into the top-scope as variables.
  def set_node_parameters
    node.parameters.each do |param, value|
      @topscope[param.to_s] = value
    end
    # These might be nil.
    catalog.client_version = node.parameters["clientversion"]
    catalog.server_version = node.parameters["serverversion"]
    if Puppet[:trusted_node_data]
      @topscope.set_trusted(node.trusted_data)
    end
    if(Puppet[:immutable_node_data])
      facts_hash = node.facts.nil? ? {} : node.facts.values
      @topscope.set_facts(facts_hash)
    end
  end

  def create_settings_scope
    settings_type = Puppet::Resource::Type.new :hostclass, "settings"
    environment.known_resource_types.add(settings_type)

    settings_resource = Puppet::Parser::Resource.new("class", "settings", :scope => @topscope)

    @catalog.add_resource(settings_resource)

    settings_type.evaluate_code(settings_resource)

    scope = @topscope.class_scope(settings_type)

    env = environment
    Puppet.settings.each do |name, setting|
      next if name == :name
      scope[name.to_s] = env[name]
    end
  end

  # Return an array of all of the unevaluated resources.  These will be definitions,
  # which need to get evaluated into native resources.
  def unevaluated_resources
    # The order of these is significant for speed due to short-circuting
    resources.reject { |resource| resource.evaluated? or resource.virtual? or resource.builtin_type? }
  end

  # Creates the injector from bindings found in the current environment.
  # @return [void]
  # @api private
  #
  def create_injector
    assert_binder_active()
    composer = Puppet::Pops::Binder::BindingsComposer.new()
    layered_bindings = composer.compose(topscope)
    @injector = Puppet::Pops::Binder::Injector.new(Puppet::Pops::Binder::Binder.new(layered_bindings))
  end

  def assert_binder_active
    unless is_binder_active?
      raise ArgumentError, "The Puppet Binder is only available when either '--binder true' or '--parser future' is used"
    end
  end
end
