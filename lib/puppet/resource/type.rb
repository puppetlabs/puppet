require 'puppet/parser'
require 'puppet/util/warnings'
require 'puppet/util/errors'
require 'puppet/parser/ast/leaf'

# Puppet::Resource::Type represents nodes, classes and defined types.
#
# It has a standard format for external consumption, usable from the
# resource_type indirection via rest and the resource_type face. See the
# {file:api_docs/http_resource_type.md#Schema resource type schema
# description}.
#
# @api public
class Puppet::Resource::Type
  Puppet::ResourceType = self
  include Puppet::Util::Warnings
  include Puppet::Util::Errors

  RESOURCE_KINDS = [:hostclass, :node, :definition, :capability_mapping, :application, :site]

  # Map the names used in our documentation to the names used internally
  RESOURCE_KINDS_TO_EXTERNAL_NAMES = {
      :hostclass => "class",
      :node => "node",
      :definition => "defined_type",
      :application => "application",
      :site => 'site'
  }
  RESOURCE_EXTERNAL_NAMES_TO_KINDS = RESOURCE_KINDS_TO_EXTERNAL_NAMES.invert

  NAME = 'name'.freeze
  TITLE = 'title'.freeze
  MODULE_NAME = 'module_name'.freeze
  CALLER_MODULE_NAME = 'caller_module_name'.freeze
  PARAMETERS = 'parameters'.freeze
  KIND = 'kind'.freeze
  NODES = 'nodes'.freeze
  DOUBLE_COLON = '::'.freeze
  EMPTY_ARRAY = [].freeze

  attr_accessor :file, :line, :doc, :code, :parent, :resource_type_collection
  attr_reader :namespace, :arguments, :behaves_like, :module_name

  # The attributes 'produces' and 'consumes' are arrays of the blueprints
  # of capabilities this type can produce/consume. The entries in the array
  # are a fairly direct representation of what goes into produces/consumes
  # clauses. Each entry is a hash with attributes
  #   :capability  - the type name of the capres produced/consumed
  #   :mappings    - a hash of attribute_name => Expression
  # These two attributes are populated in
  # PopsBridge::instantiate_CapabilityMaping

  # Map from argument (aka parameter) names to Puppet Type
  # @return [Hash<Symbol, Puppet::Pops::Types::PAnyType] map from name to type
  #
  attr_reader :argument_types

  # This should probably be renamed to 'kind' eventually, in accordance with the changes
  #  made for serialization and API usability (#14137).  At the moment that seems like
  #  it would touch a whole lot of places in the code, though.  --cprice 2012-04-23
  attr_reader :type

  RESOURCE_KINDS.each do |t|
    define_method("#{t}?") { self.type == t }
  end

  require 'puppet/indirector'
  extend Puppet::Indirector
  indirects :resource_type, :terminus_class => :parser

  def self.from_data_hash(data)
    name = data.delete(NAME) or raise ArgumentError, 'Resource Type names must be specified'
    kind = data.delete(KIND) || 'definition'

    unless type = RESOURCE_EXTERNAL_NAMES_TO_KINDS[kind]
      raise ArgumentError, "Unsupported resource kind '#{kind}'"
    end

    data = data.inject({}) { |result, ary| result[ary[0].intern] = ary[1]; result }

    # External documentation uses "parameters" but the internal name
    # is "arguments"
    data[:arguments] = data.delete(:parameters)

    new(type, name, data)
  end

  def to_data_hash
    data = [:doc, :line, :file, :parent].inject({}) do |hash, param|
      next hash unless (value = self.send(param)) and (value != "")
      hash[param.to_s] = value
      hash
    end

    # External documentation uses "parameters" but the internal name
    # is "arguments"
    # Dump any arguments as source
    data[PARAMETERS] = Hash[arguments.map do |k,v|
                                [k, v.respond_to?(:source_text) ? v.source_text : v]
                              end]
    data[NAME] = name

    unless RESOURCE_KINDS_TO_EXTERNAL_NAMES.has_key?(type)
      raise ArgumentError, "Unsupported resource kind '#{type}'"
    end
    data[KIND] = RESOURCE_KINDS_TO_EXTERNAL_NAMES[type]
    data
  end

  # Are we a child of the passed class?  Do a recursive search up our
  # parentage tree to figure it out.
  def child_of?(klass)
    return false unless parent

    return(klass == parent_type ? true : parent_type.child_of?(klass))
  end

  # Evaluate the resources produced by the given resource. These resources are
  # evaluated in a separate but identical scope from the rest of the resource.
  def evaluate_produces(resource, scope)
    # Only defined types can produce capabilities
    return unless definition?

    resource.export.map do |ex|
      # Assert that the ref really is a resource reference
      raise Puppet::Error, "Invalid export in #{resource.ref}: #{ex} is not a resource" unless ex.is_a?(Puppet::Resource)
      raise Puppet::Error, "Invalid export in #{resource.ref}: #{ex} is not a capability resource" if ex.resource_type.nil? || !ex.resource_type.is_capability?

      blueprint = produces.find { |pr| pr[:capability] == ex.type }
      if blueprint.nil?
        raise Puppet::ParseError, "Resource type #{resource.type} does not produce #{ex.type}"
      end
      produced_resource = Puppet::Parser::Resource.new(ex.type, ex.title, :scope => scope, :source => self)

      produced_resource.resource_type.parameters.each do |name|
        next if name == :name

        if expr = blueprint[:mappings][name.to_s]
          produced_resource[name] = expr.safeevaluate(scope)
        else
          produced_resource[name] = scope[name.to_s]
        end
      end
      # Tag the produced resource so we can later distinguish it from
      # copies of the resource that wind up in the catalogs of nodes that
      # use this resource. We tag the resource with producer:<environment>,
      # meaning produced resources need to be unique within their
      # environment
      # @todo lutter 2014-11-13: we would really like to use a dedicated
      # metadata field to indicate the producer of a resource, but that
      # requires changes to PuppetDB and its API; so for now, we just use
      # tagging
      produced_resource.tag("producer:#{scope.catalog.environment}")
      scope.catalog.add_resource(produced_resource)
      produced_resource[:require] = resource.ref
      produced_resource
    end
  end

  # Now evaluate the code associated with this class or definition.
  def evaluate_code(resource)

    static_parent = evaluate_parent_type(resource)
    scope = static_parent || resource.scope

    scope = scope.newscope(:namespace => namespace, :source => self, :resource => resource) unless resource.title == :main
    scope.compiler.add_class(name) unless definition?

    set_resource_parameters(resource, scope)

    resource.add_edge_to_stage

    evaluate_produces(resource, scope)

    if code
      if @match # Only bother setting up the ephemeral scope if there are match variables to add into it
        begin
          elevel = scope.ephemeral_level
          scope.ephemeral_from(@match, file, line)
          code.safeevaluate(scope)
        ensure
          scope.unset_ephemeral_var(elevel)
        end
      else
        code.safeevaluate(scope)
      end
    end
  end

  def initialize(type, name, options = {})
    @type = type.to_s.downcase.to_sym
    raise ArgumentError, "Invalid resource supertype '#{type}'" unless RESOURCE_KINDS.include?(@type)

    name = convert_from_ast(name) if name.is_a?(Puppet::Parser::AST::HostName)

    set_name_and_namespace(name)

    [:code, :doc, :line, :file, :parent].each do |param|
      next unless value = options[param]
      send(param.to_s + '=', value)
    end

    set_arguments(options[:arguments])
    set_argument_types(options[:argument_types])

    @match = nil

    @module_name = options[:module_name]
  end

  def produces
    @produces || EMPTY_ARRAY
  end

  def consumes
    @consumes || EMPTY_ARRAY
  end

  def add_produces(blueprint)
    @produces ||= []
    @produces << blueprint
  end

  def add_consumes(blueprint)
    @consumes ||= []
    @consumes << blueprint
  end

  # This is only used for node names, and really only when the node name
  # is a regexp.
  def match(string)
    return string.to_s.downcase == name unless name_is_regex?

    @match = @name.match(string)
  end

  # Add code from a new instance to our code.
  def merge(other)
    fail "#{name} is not a class; cannot add code to it" unless type == :hostclass
    fail "#{other.name} is not a class; cannot add code from it" unless other.type == :hostclass
    fail "Cannot have code outside of a class/node/define because 'freeze_main' is enabled" if name == "" and Puppet.settings[:freeze_main]

    if parent and other.parent and parent != other.parent
      fail "Cannot merge classes with different parent classes (#{name} => #{parent} vs. #{other.name} => #{other.parent})"
    end

    # We know they're either equal or only one is set, so keep whichever parent is specified.
    self.parent ||= other.parent

    if other.doc
      self.doc ||= ""
      self.doc += other.doc
    end

    # This might just be an empty, stub class.
    return unless other.code

    unless self.code
      self.code = other.code
      return
    end

    self.code = Puppet::Parser::ParserFactory.code_merger.concatenate([self, other])
  end

  # Make an instance of the resource type, and place it in the catalog
  # if it isn't in the catalog already.  This is only possible for
  # classes and nodes.  No parameters are be supplied--if this is a
  # parameterized class, then all parameters take on their default
  # values.
  def ensure_in_catalog(scope, parameters=nil)
    resource_type =
    case type
    when :definition
      raise ArgumentError, 'Cannot create resources for defined resource types'
    when :hostclass
      :class
    when :node
      :node
    when :site
      :site
    end

    # Do nothing if the resource already exists; this makes sure we don't
    # get multiple copies of the class resource, which helps provide the
    # singleton nature of classes.
    # we should not do this for classes with parameters
    # if parameters are passed, we should still try to create the resource
    # even if it exists so that we can fail
    # this prevents us from being able to combine param classes with include
    if parameters.nil?
      resource = scope.catalog.resource(resource_type, name)
      return resource unless resource.nil?
    elsif parameters.is_a?(Hash)
      parameters = parameters.map {|k, v| Puppet::Parser::Resource::Param.new(:name => k, :value => v, :source => self)}
    end
    resource = Puppet::Parser::Resource.new(resource_type, name, :scope => scope, :source => self, :parameters => parameters)
    instantiate_resource(scope, resource)
    scope.compiler.add_resource(scope, resource)
    resource
  end

  def instantiate_resource(scope, resource)
    # Make sure our parent class has been evaluated, if we have one.
    if parent && !scope.catalog.resource(resource.type, parent)
      parent_type(scope).ensure_in_catalog(scope)
    end

    if ['Class', 'Node'].include? resource.type
      scope.catalog.tag(*resource.tags)
    end
  end

  def name
    if type == :node && name_is_regex?
      "__node_regexp__#{@name.source.downcase.gsub(/[^-\w:.]/,'').sub(/^\.+/,'')}"
    else
      @name
    end
  end

  def name_is_regex?
    @name.is_a?(Regexp)
  end

  # @deprecated Not used by Puppet
  # @api private
  def assign_parameter_values(parameters, resource)
    Puppet.deprecation_warning('The method Puppet::Resource::Type.assign_parameter_values is deprecated and will be removed in the next major release of Puppet.')

    return unless parameters

    # It'd be nice to assign default parameter values here,
    # but we can't because they often rely on local variables
    # created during set_resource_parameters.
    parameters.each do |name, value|
      resource.set_parameter name, value
    end
  end

  def parent_type(scope = nil)
    return nil unless parent

    @parent_type ||= scope.environment.known_resource_types.send("find_#{type}", parent) ||
      fail(Puppet::ParseError, "Could not find parent resource type '#{parent}' of type #{type} in #{scope.environment}")
  end

  # Validate and set any arguments passed by the resource as variables in the scope.
  # @param resource [Puppet::Parser::Resource] the resource
  # @param scope [Puppet::Parser::Scope] the scope
  #
  # @api private
  def set_resource_parameters(resource, scope)
    # Inject parameters from using external lookup
    resource.add_parameters_from_consume
    inject_external_parameters(resource, scope)

    resource_hash = {}
    resource.each { |k, v| resource_hash[k.to_s] = v.value unless k == :name || k == :title }

    if @type == :hostclass
      scope[TITLE] = resource.title.to_s.downcase
      scope[NAME] =  resource.name.to_s.downcase
    else
      scope[TITLE] = resource.title
      scope[NAME] =  resource.name
    end

    modname = resource_hash[MODULE_NAME] || module_name
    scope[MODULE_NAME] = modname unless modname.nil?
    caller_name = resource_hash[CALLER_MODULE_NAME] || scope.parent_module_name
    scope[CALLER_MODULE_NAME] = caller_name unless caller_name.nil?

    scope.class_set(self.name,scope) if hostclass? || node?

    assign_defaults(resource, scope, resource_hash)
    validate_resource_hash(resource, resource_hash)
    resource_hash.each { |param, value| exceptwrap { scope[param] = value }}
  end

  # Lookup and inject parameters from external scope
  # @param resource [Puppet::Parser::Resource] the resource
  # @param scope [Puppet::Parser::Scope] the scope
  def inject_external_parameters(resource, scope)
    # Only lookup parameters for host classes
    return unless type == :hostclass
    parameters = resource.parameters
    arguments.each do |param_name, _|
      name = param_name.to_sym
      next if parameters.include?(name)
      value = lookup_external_default_for(param_name, scope)
      resource[name] = value unless value.nil?
    end
  end
  private :inject_external_parameters

  def assign_defaults(resource, scope, resource_hash)
    return unless resource.is_a?(Puppet::Parser::Resource)
    parameters = resource.parameters
    hashed_types = parameter_struct.hashed_elements
    arguments.each do |param_name, default|
      next if default.nil?
      name = param_name.to_sym
      param = parameters[name]
      next unless param.nil? || param.value.nil?

      value = default.safeevaluate(scope)
      resource[name] = value
      resource_hash[param_name] = value
    end
  end
  private :assign_defaults

  def validate_resource_hash(resource, resource_hash)
    Puppet::Pops::Types::TypeMismatchDescriber.validate_parameters(resource.to_s, parameter_struct, resource_hash)
  end
  private :validate_resource_hash

  # Validate that all parameters given to the resource are correct
  # @param resource [Puppet::Resource] the resource to validate
  def validate_resource(resource)
    validate_resource_hash(resource, Hash[resource.parameters.map { |name, value| [name.to_s, value.value] }])
  end

  # Check whether a given argument is valid.
  def valid_parameter?(param)
    parameter_struct.hashed_elements.include?(param.to_s)
  end

  def set_arguments(arguments)
    @arguments = {}
    @parameter_struct = nil
    return if arguments.nil?

    arguments.each do |arg, default|
      arg = arg.to_s
      warn_if_metaparam(arg, default)
      @arguments[arg] = default
    end
  end

  # Sets the argument name to Puppet Type hash used for type checking.
  # Names must correspond to available arguments (they must be defined first).
  # Arguments not mentioned will not be type-checked.
  #
  def set_argument_types(name_to_type_hash)
    @argument_types = {}
    @parameter_struct = nil
    return unless name_to_type_hash
    name_to_type_hash.each do |name, t|
      # catch internal errors
      unless @arguments.include?(name)
        raise Puppet::DevError, "Parameter '#{name}' is given a type, but is not a valid parameter."
      end
      unless t.is_a? Puppet::Pops::Types::PAnyType
        raise Puppet::DevError, "Parameter '#{name}' is given a type that is not a Puppet Type, got #{t.class}"
      end
      @argument_types[name] = t
    end
  end

  # Returns boolean true if an instance of this type is a capability. This
  # implementation always returns false. This "duck-typing" interface is
  # shared among other classes and makes it easier to detect capabilities
  # when they are intermixed with non capability instances.
  def is_capability?
    false
  end

  private

  def convert_from_ast(name)
    value = name.value
    if value.is_a?(Puppet::Parser::AST::Regex)
      name = value.value
    else
      name = value
    end
  end

  def evaluate_parent_type(resource)
    return unless klass = parent_type(resource.scope) and parent_resource = resource.scope.compiler.catalog.resource(:class, klass.name) || resource.scope.compiler.catalog.resource(:node, klass.name)
    parent_resource.evaluate unless parent_resource.evaluated?
    parent_scope(resource.scope, klass)
  end

  # Split an fq name into a namespace and name
  def namesplit(fullname)
    ary = fullname.split(DOUBLE_COLON)
    n = ary.pop || ""
    ns = ary.join(DOUBLE_COLON)
    return ns, n
  end

  def parent_scope(scope, klass)
    scope.class_scope(klass) || raise(Puppet::DevError, "Could not find scope for #{klass.name}")
  end

  def set_name_and_namespace(name)
    if name.is_a?(Regexp)
      @name = name
      @namespace = ""
    else
      @name = name.to_s.downcase

      # Note we're doing something somewhat weird here -- we're setting
      # the class's namespace to its fully qualified name.  This means
      # anything inside that class starts looking in that namespace first.
      @namespace, ignored_shortname = @type == :hostclass ? [@name, ''] : namesplit(@name)
    end
  end

  def warn_if_metaparam(param, default)
    return unless Puppet::Type.metaparamclass(param)

    if default
      warnonce "#{param} is a metaparam; this value will inherit to all contained resources in the #{self.name} definition"
    else
      raise Puppet::ParseError, "#{param} is a metaparameter; please choose another parameter name in the #{self.name} definition"
    end
  end

  def parameter_struct
    @parameter_struct ||= create_params_struct
  end

  def create_params_struct
    arg_types = argument_types
    type_factory = Puppet::Pops::Types::TypeFactory
    members = { type_factory.optional(type_factory.string(nil, NAME)) =>  type_factory.any }

    if application?
      resource_type = type_factory.type_type(type_factory.resource)
      members[type_factory.optional(type_factory.string(nil, NODES))] = type_factory.hash_of(type_factory.variant(
          resource_type, type_factory.array_of(resource_type)), type_factory.type_type(type_factory.resource('node')))
    end

    Puppet::Type.eachmetaparam do |name|
      # TODO: Once meta parameters are typed, this should change to reflect that type
      members[name.to_s] = type_factory.any
    end

    arguments.each_pair do |name, default|
      key_type = type_factory.string(nil, name.to_s)
      key_type = type_factory.optional(key_type) unless default.nil?

      arg_type = arg_types[name]
      arg_type = type_factory.any if arg_type.nil?
      members[key_type] = arg_type
    end
    type_factory.struct(members)
  end
  private :create_params_struct

  # Consult external data bindings for class parameter values which must be
  # namespaced in the backend.
  #
  # Example:
  #
  #   class foo($port=0){ ... }
  #
  # We make a request to the backend for the key 'foo::port' not 'foo'
  #
  def lookup_external_default_for(param, scope)
    return unless type == :hostclass
    qname = "#{name}::#{param}"
    in_global = lambda { lookup_with_databinding(qname, scope) }
    in_env = lambda { lookup_in_environment(qname, scope) }
    in_module = lambda { lookup_in_module(qname, scope) }
    lookup_search(in_global, in_env, in_module)
  end
  private :lookup_external_default_for

  def lookup_search(*search_functions)
    search_functions.each {|f| x = f.call(); return x unless x.nil? }
    nil
  end
  private :lookup_search

  def lookup_with_databinding(name, scope)
    begin
      found = false
      value = catch(:no_such_key) do
        v = Puppet::DataBinding.indirection.find(
          name,
          :environment => scope.environment.to_s,
          :variables => scope)
        found = true
        v
      end
      found ? value : nil
    rescue Puppet::DataBinding::LookupError => e
      raise Puppet::Error.new("Error from DataBinding '#{Puppet[:data_binding_terminus]}' while looking up '#{name}': #{e.message}", e)
    end
  end
  private :lookup_with_databinding

  def lookup_in_environment(name, scope)
    found = false
    value = catch(:no_such_key) do
      v = Puppet::DataProviders.lookup_in_environment(name, Puppet::Pops::Lookup::Invocation.new(scope), nil)
      found = true
      v
    end
    found ? value : nil
  end
  private :lookup_in_environment

  def lookup_in_module(name, scope)
    found = false
    value = catch(:no_such_key) do
      v = Puppet::DataProviders.lookup_in_module(name, Puppet::Pops::Lookup::Invocation.new(scope), nil)
      found = true
      v
    end
    found ? value : nil
  end
  private :lookup_in_module
end
