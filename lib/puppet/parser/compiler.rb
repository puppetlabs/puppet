require 'forwardable'

require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/util/errors'

require 'puppet/resource/type_collection_helper'
require 'puppet/loaders'
require 'puppet/pops'

# Maintain a graph of scopes, along with a bunch of data
# about the individual catalog we're compiling.
class Puppet::Parser::Compiler
  extend Forwardable

  include Puppet::Util
  include Puppet::Util::Errors
  include Puppet::Util::MethodHelper
  include Puppet::Resource::TypeCollectionHelper
  include Puppet::Pops::Evaluator::Runtime3Support

  def self.compile(node, code_id = nil)
    node.environment.check_for_reparse

    errors = node.environment.validation_errors
    if !errors.empty?
      errors.each { |e| Puppet.err(e) } if errors.size > 1
      errmsg = [
        "Compilation has been halted because: #{errors.first}",
        "For more information, see https://docs.puppet.com/puppet/latest/reference/environments.html",
      ]
      raise(Puppet::Error, errmsg.join(' '))
    end

    new(node, :code_id => code_id).compile {|resulting_catalog| resulting_catalog.to_resource }
  rescue Puppet::ParseErrorWithIssue => detail
    detail.node = node.name
    Puppet.log_exception(detail)
    raise
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

  # The id of code input to the compiler.
  # @api private
  attr_accessor :code_id

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
    type = resource.resource_type
    if type.is_a?(Puppet::Resource::Type) && type.application?
      @applications << resource
      assert_app_in_site(scope, resource)
      return
    end

    if @current_app
      # We are in the process of pulling application components out that
      # apply to this node
      Puppet.notice "Check #{resource}"
      return unless @current_components.any? do |comp|
        comp.type == resource.type && comp.title == resource.title
      end
    end

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
      @catalog.add_edge(scope.resource, resource)
    end
  end

  def assert_app_in_site(scope, resource)
    if resource.type == 'App'
      if scope.resource
        # directly contained in a Site
        return if scope.resource.type == 'Site'
        # contained in something that may be contained in Site
        upstream = @catalog.upstream_from_vertex(scope.resource)
        if upstream
          return if upstream.keys.map(&:type).include?('Site')
        end
      end
      raise ArgumentError, "Application instances like '#{resource}' can only be contained within a Site"
    end
  end

  # Do we use nodes found in the code, vs. the external node sources?
  def_delegator :known_resource_types, :nodes?, :ast_nodes?

  # Store the fact that we've evaluated a class
  def add_class(name)
    @catalog.add_class(name) unless name == ""
  end

  # Add a catalog validator that will run at some stage to this compiler
  # @param catalog_validators [Class<CatalogValidator>] The catalog validator class to add
  def add_catalog_validator(catalog_validators)
    @catalog_validators << catalog_validators
    nil
  end

  def add_catalog_validators
    add_catalog_validator(CatalogValidator::RelationshipValidator)
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

      activate_binder

      Puppet::Util::Profiler.profile("Compile: Evaluated capability mappings", [:compiler, :evaluate_capability_mappings]) { evaluate_capability_mappings }

      Puppet::Util::Profiler.profile("Compile: Evaluated main", [:compiler, :evaluate_main]) { evaluate_main }

      Puppet::Util::Profiler.profile("Compile: Evaluated site", [:compiler, :evaluate_site]) { evaluate_site }

      Puppet::Util::Profiler.profile("Compile: Evaluated AST node", [:compiler, :evaluate_ast_node]) { evaluate_ast_node }

      Puppet::Util::Profiler.profile("Compile: Evaluated node classes", [:compiler, :evaluate_node_classes]) { evaluate_node_classes }

      Puppet::Util::Profiler.profile("Compile: Evaluated application instances", [:compiler, :evaluate_applications]) { evaluate_applications }

      # New capability mappings may have been defined when the site was evaluated
      Puppet::Util::Profiler.profile("Compile: Evaluated site capability mappings", [:compiler, :evaluate_capability_mappings]) { evaluate_capability_mappings }

      Puppet::Util::Profiler.profile("Compile: Evaluated generators", [:compiler, :evaluate_generators]) { evaluate_generators }

      Puppet::Util::Profiler.profile("Compile: Validate Catalog pre-finish", [:compiler, :validate_pre_finish]) do
        validate_catalog(CatalogValidator::PRE_FINISH)
      end

      Puppet::Util::Profiler.profile("Compile: Finished catalog", [:compiler, :finish_catalog]) { finish }

      Puppet::Util::Profiler.profile("Compile: Prune", [:compiler, :prune_catalog]) { prune_catalog }

      fail_on_unevaluated

      Puppet::Util::Profiler.profile("Compile: Validate Catalog final", [:compiler, :validate_final]) do
        validate_catalog(CatalogValidator::FINAL)
      end

      if block_given?
        yield @catalog
      else
        @catalog
      end
    end
  end

  def validate_catalog(validation_stage)
    @catalog_validators.select { |vclass| vclass.validation_stage?(validation_stage) }.each { |vclass| vclass.new(@catalog).validate }
  end

  # Constructs the overrides for the context
  def context_overrides()
    {
      :current_environment => environment,
      :global_scope => @topscope,             # 4x placeholder for new global scope
      :loaders  => lambda {|| loaders() },    # 4x loaders
      :injector => lambda {|| injector() }    # 4x API - via context instead of via compiler
    }
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

    evaluate_classes(classes_with_params, @node_scope || topscope)
    evaluate_classes(classes_without_params, @node_scope || topscope)
  end

  # Evaluates the site - the top container for an environment catalog
  # The site contain behaves analogous to a node - for the environment catalog, node expressions are ignored
  # as the result is cross node. The site expression serves as a container for everything that is across
  # all nodes.
  #
  # @api private
  #
  def evaluate_site
    # Has a site been defined? If not, do nothing but issue a warning.
    #
    site = known_resource_types.find_site()
    unless site
      on_empty_site()
      return
    end

    # Create a resource to model this site and add it to catalog
    resource = site.ensure_in_catalog(topscope)

    # The site sets node scope to be able to shadow what is in top scope
    @node_scope = topscope.class_scope(site)

    # Evaluates the logic contain in the site expression
    resource.evaluate
  end

  # @api private
  def on_empty_site
    # do nothing
  end

  # Prunes the catalog by dropping all resources are contained under the Site (if a site expression is used).
  # As a consequence all edges to/from dropped resources are also dropped.
  # Once the pruning is performed, this compiler returns the pruned list when calling the #resources method.
  # The pruning does not alter the order of resources in the resources list.
  #
  # @api private
  def prune_catalog
    prune_node_catalog
  end

  def prune_node_catalog
    # Everything under Site[site] should be pruned as that is for the environment catalog, not a node
    #
    the_site_resource = @catalog.resource('Site', 'site')

    if the_site_resource
      # Get downstream vertexes returns a hash where the keys are the resources and values nesting level
      to_be_removed = @catalog.downstream_from_vertex(the_site_resource).keys

      # Drop the Site[site] resource if it has no content
      if to_be_removed.empty?
        to_be_removed << the_site_resource
      end
    else
      to_be_removed = []
    end

    # keep_from_site is populated with any App resources.
    application_resources = @resources.select {|r| r.type == 'App' }
    # keep all applications plus what is directly referenced from applications
    keep_from_site = application_resources
    keep_from_site += application_resources.map {|app| @catalog.direct_dependents_of(app) }.flatten

    to_be_removed -= keep_from_site
    @catalog.remove_resource(*to_be_removed)
    # set the pruned result
    @resources = @catalog.resources
  end

  # @api private
  def evaluate_applications
    @applications.each do |app|
      components = []
      mapping = app.parameters[:nodes] ? app.parameters[:nodes].value : {}
      raise Puppet::Error, "Invalid node mapping in #{app.ref}: Mapping must be a hash" unless mapping.is_a?(Hash)
      all_mapped = Set.new
      mapping.each do |k,v|
        raise Puppet::Error, "Invalid node mapping in #{app.ref}: Key #{k} is not a Node" unless k.is_a?(Puppet::Resource) && k.type == 'Node'
        v = [v] unless v.is_a?(Array)
        v.each do |res|
          raise Puppet::Error, "Invalid node mapping in #{app.ref}: Value #{res} is not a resource" unless res.is_a?(Puppet::Resource)
          raise Puppet::Error, "Application #{app.ref} maps component #{res} to multiple nodes" if all_mapped.add?(res.ref).nil?
          components << res if k.title == node.name
        end
      end
      begin
        @current_app = app
        @current_components = components
        unless @current_components.empty?
          Puppet.notice "EVAL APP #{app} #{components.inspect}"
          # Add the app itself since components mapped to the current node
          # will have a containment edge for it
          # @todo lutter 2015-01-28: the node mapping winds up in the
          # catalog, but probably shouldn't
          @catalog.add_resource(@current_app)
          @current_app.evaluate
        end
      ensure
        @current_app = nil
        @current_components = nil
      end
    end
  end

  # Evaluates each specified class in turn. If there are any classes that 
  # can't be found, an error is raised. This method really just creates resource objects
  # that point back to the classes, and then the resources are themselves
  # evaluated later in the process.
  #
  def evaluate_classes(classes, scope, lazy_evaluate = true)
    raise Puppet::DevError, "No source for scope passed to evaluate_classes" unless scope.source
    class_parameters = nil
    # if we are a param class, save the classes hash
    # and transform classes to be the keys
    if classes.class == Hash
      class_parameters = classes
      classes = classes.keys
    end

    unless @current_components.nil?
      classes = classes.select do |title|
        @current_components.any? { |comp| comp.class? && comp.title == title }
      end
    end

    hostclasses = classes.collect do |name|
      scope.find_hostclass(name) or raise Puppet::Error, "Could not find class #{name} for #{node.name}"
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
    @node = sanitize_node(node)
    # Array of resources representing all application instances we've found
    @applications = []
    # We use @current_app and @current_components to signal to the
    # evaluator that we are in the middle of evaluating an
    # application. They are set in evaluate_applications to the application
    # instance, resp. to an array of the components of that application
    # that is mapped to the current node. They are only non-nil when we are
    # in the middle of executing evaluate_applications
    @current_app = nil
    @current_components = nil
    set_options(options)
    initvars
    add_catalog_validators
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
  def activate_binder
    # TODO: this should be in a central place
    Puppet::Parser::ParserFactory.assert_rgen_installed()
    @@binder_loaded ||= false
    unless @@binder_loaded
      require 'puppet/pops'
      require 'puppet/plugins/configuration'
      @@binder_loaded = true
    end
    true
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

  def evaluate_capability_mappings
    krt = known_resource_types
    krt.capability_mappings.each_value do |capability_mapping|
      args = capability_mapping.arguments
      component_ref = args['component']
      kind = args['kind']

      # That component_ref is either a QNAME or a Class['literal'|QREF] is asserted during validation so no
      # need to check that here
      if component_ref.is_a?(Puppet::Pops::Model::QualifiedName)
        component_name = component_ref.value
        component_type = 'type'
        component = krt.find_definition(component_name)
      else
        component_name = component_ref.keys[0].value
        component_type = 'class'
        component = krt.find_hostclass(component_name)
      end
      if component.nil?
        raise Puppet::ParseError, "Capability mapping error: #{kind} clause references nonexistent #{component_type} #{component_name}"
      end

      blueprint = args['blueprint']
      if kind == 'produces'
        component.add_produces(blueprint)
      else
        component.add_consumes(blueprint)
      end
    end
    krt.capability_mappings.clear # No longer needed
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
      raise Puppet::ParseError, "Could not find node statement with name 'default' or '#{node.names.join(", ")}'"
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
        urs = unevaluated_resources.each do |resource|
         begin
            resource.evaluate
          rescue Puppet::Error => e
            # PuppetError has the ability to wrap an exception, if so, use the wrapped exception's
            # call stack instead
            fail(Puppet::Pops::Issues::RUNTIME_ERROR, resource, {:detail => e.message}, e.original || e)
          end
        end
        !urs.empty?
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
    @main = known_resource_types.find_hostclass("") || known_resource_types.add(Puppet::Resource::Type.new(:hostclass, ""))
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
      raise Puppet::ParseError, "Could not find resource(s) #{remaining.join(', ')} for overriding"
    end
  end

  # Make sure there are no remaining collections that are waiting for
  # resources that have not yet been instantiated. If this occurs it
  # is an error (missing resource - it could not be realized).
  #
  def fail_on_unevaluated_resource_collections
    remaining = @collections.collect(&:unresolved_resources).flatten.compact
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
    @catalog = Puppet::Resource::Catalog.new(@node.name, @node.environment, @code_id)

    # MOVED HERE - SCOPE IS NEEDED (MOVE-SCOPE)
    # Create the initial scope, it is needed early
    @topscope = Puppet::Parser::Scope.new(self)

    # Need to compute overrides here, and remember them, because we are about to
    # enter the magic zone of known_resource_types and initial import.
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

    @catalog_validators = []
  end

  def sanitize_node(node)
    # Resurrect "trusted information" that comes from node/fact terminus.
    # The current way this is done in puppet db (currently the only one)
    # is to store the node parameter 'trusted' as a hash of the trusted information.
    #
    # Thus here there are two main cases:
    # 1. This terminus was used in a real agent call (only meaningful if someone curls the request as it would
    #  fail since the result is a hash of two catalogs).
    # 2  It is a command line call with a given node that use a terminus that:
    # 2.1 does not include a 'trusted' fact - use local from node trusted information
    # 2.2 has a 'trusted' fact - this in turn could be
    # 2.2.1 puppet db having stored trusted node data as a fact (not a great design)
    # 2.2.2 some other terminus having stored a fact called "trusted" (most likely that would have failed earlier, but could
    #       be spoofed).
    #
    # For the reasons above, the resurection of trusted node data with authenticated => true is only performed
    # if user is running as root, else it is resurrected as unauthenticated.
    #
    trusted_param = node.parameters['trusted']
    if trusted_param
      # Blows up if it is a parameter as it will be set as $trusted by the compiler as if it was a variable
      node.parameters.delete('trusted')
      unless trusted_param.is_a?(Hash) && %w{authenticated certname extensions}.all? {|key| trusted_param.has_key?(key) }
        # trusted is some kind of garbage, do not resurrect
        trusted_param = nil
      end
    else
      # trusted may be boolean false if set as a fact by someone
      trusted_param = nil
    end

    # The options for node.trusted_data in priority order are:
    # 1) node came with trusted_data so use that
    # 2) else if there is :trusted_information in the puppet context
    # 3) else if the node provided a 'trusted' parameter (parsed out above)
    # 4) last, fallback to local node trusted information
    #
    # Note that trusted_data should be a hash, but (2) and (4) are not
    # hashes, so we to_h at the end
    if !node.trusted_data
      trusted = Puppet.lookup(:trusted_information) do
        trusted_param || Puppet::Context::TrustedInformation.local(node)
      end

      # Ruby 1.9.3 can't apply to_h to a hash, so check first
      node.trusted_data = trusted.is_a?(Hash) ? trusted : trusted.to_h
    end

    node
  end

  # Set the node's parameters into the top-scope as variables.
  def set_node_parameters
    node.parameters.each do |param, value|
      # Ensure node does not leak Symbol instances in general
      @topscope[param.to_s] = value.is_a?(Symbol) ? value.to_s : value
    end
    # These might be nil.
    catalog.client_version = node.parameters["clientversion"]
    catalog.server_version = node.parameters["serverversion"]
    @topscope.set_trusted(node.trusted_data)

    if Puppet[:trusted_server_facts]
      @topscope.set_server_facts(node.server_facts)
    end

    facts_hash = node.facts.nil? ? {} : node.facts.values
    @topscope.set_facts(facts_hash)
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
    unless activate_binder()
      raise Puppet::DevError, "The Puppet Binder was not activated"
    end
  end  # Creates a diagnostic producer
end
