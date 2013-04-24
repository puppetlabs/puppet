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
    # We get these from the environment and only cache them in a thread
    # variable for the duration of the compilation.  If nothing else is using
    # the thread, though, we can leave 'em hanging round with no ill effects,
    # and this is safer than cleaning them at the end and assuming that will
    # stick until the next entry to this function.
    Thread.current[:known_resource_types] = nil
    Thread.current[:env_module_directories] = nil

    # ...and we actually do the compile now we have caching ready.
    new(node).compile.to_resource
  rescue => detail
    message = "#{detail} on node #{node.name}"
    Puppet.log_exception(detail, message)
    raise Puppet::Error, message, detail.backtrace
 end

  attr_reader :node, :facts, :collections, :catalog, :resources, :relationships, :topscope

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

  # Store a resource in our resource table.
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
    # Set the client's parameters into the top scope.
    Puppet::Util::Profiler.profile("Compile: Set node parameters") { set_node_parameters }

    Puppet::Util::Profiler.profile("Compile: Created settings scope") { create_settings_scope }

    Puppet::Util::Profiler.profile("Compile: Evaluated main") { evaluate_main }

    Puppet::Util::Profiler.profile("Compile: Evaluated AST node") { evaluate_ast_node }

    Puppet::Util::Profiler.profile("Compile: Evaluated node classes") { evaluate_node_classes }

    Puppet::Util::Profiler.profile("Compile: Evaluated generators") { evaluate_generators }

    Puppet::Util::Profiler.profile("Compile: Finished catalog") { finish }

    fail_on_unevaluated

    @catalog
  end

  def_delegator :@collections, :delete, :delete_collection

  # Return the node's environment.
  def environment
    unless defined?(@environment)
      unless node.environment.is_a? Puppet::Node::Environment
        raise Puppet::DevError, "node #{node} has an invalid environment!"
      end
      @environment = node.environment
    end
    Puppet::Node::Environment.current = @environment
    @environment
  end

  # Evaluate all of the classes specified by the node.
  def evaluate_node_classes
    evaluate_classes(@node.classes, @node_scope || topscope)
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
    classes.each do |name|
      # If we can find the class, then make a resource that will evaluate it.
      if klass = scope.find_hostclass(name, :assume_fqname => fqname)

        # If parameters are passed, then attempt to create a duplicate resource
        # so the appropriate error is thrown.
        if class_parameters
          resource = klass.ensure_in_catalog(scope, class_parameters[name] || {})
        else
          next if scope.class_scope(klass)
          resource = klass.ensure_in_catalog(scope)
        end

        # If they've disabled lazy evaluation (which the :include function does),
        # then evaluate our resource immediately.
        resource.evaluate unless lazy_evaluate
      else
        raise Puppet::Error, "Could not find class #{name} for #{node.name}"
      end
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

  private

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
      Puppet::Util::Profiler.profile("Evaluated collections") do
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
      Puppet::Util::Profiler.profile("Evaluated definitions") do
        !unevaluated_resources.each do |resource|
          Puppet::Util::Profiler.profile("Evaluated resource #{resource}") do
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

      Puppet::Util::Profiler.profile("Iterated (#{count + 1}) on generators") do
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
    remaining = []
    @resource_overrides.each do |name, overrides|
      remaining.concat overrides
    end

    unless remaining.empty?
      fail Puppet::ParseError,
        "Could not find resource(s) %s for overriding" % remaining.collect { |o|
          o.ref
        }.join(", ")
    end
  end

  # Make sure we don't have any remaining collections that specifically
  # look for resources, because we want to consider those to be
  # parse errors.
  def fail_on_unevaluated_resource_collections
    remaining = []
    @collections.each do |coll|
      # We're only interested in the 'resource' collections,
      # which result from direct calls of 'realize'.  Anything
      # else is allowed not to return resources.
      # Collect all of them, so we have a useful error.
      if r = coll.resources
        if r.is_a?(Array)
          remaining += r
        else
          remaining << r
        end
      end
    end

    raise Puppet::ParseError, "Failed to realize virtual resources #{remaining.join(', ')}" unless remaining.empty?
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

    names = []
    Puppet::Type.eachmetaparam do |name|
      next if Puppet::Parser::Resource.relationship_parameter?(name)
      names << name
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
    # The list of objects that will available for export.
    @exported_resources = {}

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
    @catalog = Puppet::Resource::Catalog.new(@node.name)
    @catalog.version = known_resource_types.version

    @catalog.environment = @node.environment.to_s

    # Create our initial scope and a resource that will evaluate main.
    @topscope = Puppet::Parser::Scope.new(self)

    @main_stage_resource = Puppet::Parser::Resource.new("stage", :main, :scope => @topscope)
    @catalog.add_resource(@main_stage_resource)

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
  end

  def create_settings_scope
    unless settings_type = environment.known_resource_types.hostclass("settings")
      settings_type = Puppet::Resource::Type.new :hostclass, "settings"
      environment.known_resource_types.add(settings_type)
    end

    settings_resource = Puppet::Parser::Resource.new("class", "settings", :scope => @topscope)

    @catalog.add_resource(settings_resource)

    settings_type.evaluate_code(settings_resource)

    scope = @topscope.class_scope(settings_type)

    Puppet.settings.each do |name, setting|
      next if name.to_s == "name"
      scope[name.to_s] = environment[name]
    end
  end

  # Return an array of all of the unevaluated resources.  These will be definitions,
  # which need to get evaluated into native resources.
  def unevaluated_resources
    # The order of these is significant for speed due to short-circuting
    resources.reject { |resource| resource.evaluated? or resource.virtual? or resource.builtin_type? }
  end
end
