# frozen_string_literal: true
require_relative '../../puppet/parser'
require_relative '../../puppet/util/warnings'
require_relative '../../puppet/util/errors'
require_relative '../../puppet/parser/ast/leaf'

# Puppet::Resource::Type represents nodes, classes and defined types.
#
# @api public
class Puppet::Resource::Type
  Puppet::ResourceType = self
  include Puppet::Util::Warnings
  include Puppet::Util::Errors

  RESOURCE_KINDS = [:hostclass, :node, :definition]

  # Map the names used in our documentation to the names used internally
  RESOURCE_KINDS_TO_EXTERNAL_NAMES = {
      :hostclass => "class",
      :node => "node",
      :definition => "defined_type"
  }
  RESOURCE_EXTERNAL_NAMES_TO_KINDS = RESOURCE_KINDS_TO_EXTERNAL_NAMES.invert

  NAME = 'name'
  TITLE = 'title'
  MODULE_NAME = 'module_name'
  CALLER_MODULE_NAME = 'caller_module_name'
  PARAMETERS = 'parameters'
  KIND = 'kind'
  NODES = 'nodes'
  DOUBLE_COLON = '::'
  EMPTY_ARRAY = [].freeze

  attr_accessor :file, :line, :doc, :code, :parent, :resource_type_collection, :override
  attr_reader :namespace, :arguments, :behaves_like, :module_name

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

  # Are we a child of the passed class?  Do a recursive search up our
  # parentage tree to figure it out.
  def child_of?(klass)
    return true if override
    return false unless parent

    return(klass == parent_type ? true : parent_type.child_of?(klass))
  end

  # Now evaluate the code associated with this class or definition.
  def evaluate_code(resource)

    static_parent = evaluate_parent_type(resource)
    scope = static_parent || resource.scope

    scope = scope.newscope(:source => self, :resource => resource) unless resource.title == :main
    scope.compiler.add_class(name) unless definition?

    set_resource_parameters(resource, scope)

    resource.add_edge_to_stage

    if code
      if @match # Only bother setting up the ephemeral scope if there are match variables to add into it
        scope.with_guarded_scope do
          scope.ephemeral_from(@match, file, line)
          code.safeevaluate(scope)
        end
      else
        code.safeevaluate(scope)
      end
    end
  end

  def initialize(type, name, options = {})
    @type = type.to_s.downcase.to_sym
    raise ArgumentError, _("Invalid resource supertype '%{type}'") % { type: type } unless RESOURCE_KINDS.include?(@type)

    name = convert_from_ast(name) if name.is_a?(Puppet::Parser::AST::HostName)

    set_name_and_namespace(name)

    [:code, :doc, :line, :file, :parent].each do |param|
      value = options[param]
      next unless value

      send(param.to_s + '=', value)
    end

    set_arguments(options[:arguments])
    set_argument_types(options[:argument_types])

    @match = nil

    @module_name = options[:module_name]
  end

  # This is only used for node names, and really only when the node name
  # is a regexp.
  def match(string)
    return string.to_s.downcase == name unless name_is_regex?

    @match = @name.match(string)
  end

  # Add code from a new instance to our code.
  def merge(other)
    fail _("%{name} is not a class; cannot add code to it") % { name: name } unless type == :hostclass
    fail _("%{name} is not a class; cannot add code from it") % { name: other.name } unless other.type == :hostclass

    if name == "" && Puppet.settings[:freeze_main]
      # It is ok to merge definitions into main even if freeze is on (definitions are nodes, classes, defines, functions, and types)
      unless other.code.is_definitions_only?
        fail _("Cannot have code outside of a class/node/define because 'freeze_main' is enabled")
      end
    end
    if parent and other.parent and parent != other.parent
      fail _("Cannot merge classes with different parent classes (%{name} => %{parent} vs. %{other_name} => %{other_parent})") % { name: name, parent: parent, other_name: other.name, other_parent: other.parent }
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
      raise ArgumentError, _('Cannot create resources for defined resource types')
    when :hostclass
      :class
    when :node
      :node
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
      scope.catalog.merge_tags_from(resource)
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

  def parent_type(scope = nil)
    return nil unless parent

    @parent_type ||= scope.environment.known_resource_types.send("find_#{type}", parent) ||
      fail(Puppet::ParseError, _("Could not find parent resource type '%{parent}' of type %{parent_type} in %{env}") % { parent: parent, parent_type: type, env: scope.environment })
  end

  # Validate and set any arguments passed by the resource as variables in the scope.
  #
  # This method is known to only be used on the server/compile side.
  #
  # @param resource [Puppet::Parser::Resource] the resource
  # @param scope [Puppet::Parser::Scope] the scope
  #
  # @api private
  def set_resource_parameters(resource, scope)
    # Inject parameters from using external lookup
    modname = resource[:module_name] || module_name
    scope[MODULE_NAME] = modname unless modname.nil?
    caller_name = resource[:caller_module_name] || scope.parent_module_name
    scope[CALLER_MODULE_NAME] = caller_name unless caller_name.nil?

    inject_external_parameters(resource, scope)

    if @type == :hostclass
      scope[TITLE] = resource.title.to_s.downcase
      scope[NAME] =  resource.name.to_s.downcase
    else
      scope[TITLE] = resource.title
      scope[NAME] =  resource.name
    end
    scope.class_set(self.name,scope) if hostclass? || node?

    param_hash = scope.with_parameter_scope(resource.to_s, arguments.keys) do |param_scope|
      # Assign directly to the parameter scope to avoid scope parameter validation at this point. It
      # will happen anyway when the values are assigned to the scope after the parameter scoped has
      # been popped.
      resource.each { |k, v| param_scope[k.to_s] = v.value unless k == :name || k == :title }
      assign_defaults(resource, param_scope, scope)
      param_scope.to_hash
    end

    validate_resource_hash(resource, param_hash)

    # Assign parameter values to current scope
    param_hash.each { |param, value| exceptwrap { scope[param] = value }}
  end

  # Lookup and inject parameters from external scope
  # @param resource [Puppet::Parser::Resource] the resource
  # @param scope [Puppet::Parser::Scope] the scope
  def inject_external_parameters(resource, scope)
    # Only lookup parameters for host classes
    return unless type == :hostclass

    parameters = resource.parameters
    arguments.each do |param_name, default|
      sym_name = param_name.to_sym
      param = parameters[sym_name]
      next unless param.nil? || param.value.nil?

      catch(:no_such_key) do
        bound_value = Puppet::Pops::Lookup.search_and_merge("#{name}::#{param_name}", Puppet::Pops::Lookup::Invocation.new(scope), nil)
        # Assign bound value but don't let an undef trump a default expression
        resource[sym_name] = bound_value unless bound_value.nil? && !default.nil?
      end
    end
  end
  private :inject_external_parameters

  def assign_defaults(resource, param_scope, scope)
    return unless resource.is_a?(Puppet::Parser::Resource)

    parameters = resource.parameters
    arguments.each do |param_name, default|
      next if default.nil?

      name = param_name.to_sym
      param = parameters[name]
      next unless param.nil? || param.value.nil?

      value = exceptwrap { param_scope.evaluate3x(param_name, default, scope) }
      resource[name] = value
      param_scope[param_name] = value
    end
  end
  private :assign_defaults

  def validate_resource_hash(resource, resource_hash)
    Puppet::Pops::Types::TypeMismatchDescriber.validate_parameters(resource.to_s, parameter_struct, resource_hash, false)
  end
  private :validate_resource_hash

  # Validate that all parameters given to the resource are correct
  # @param resource [Puppet::Resource] the resource to validate
  def validate_resource(resource)
    # Since Sensitive values have special encoding (in a separate parameter) an unwrapped sensitive value must be
    # recreated as a Sensitive in order to perform correct type checking.
    sensitives = Set.new(resource.sensitive_parameters)
    validate_resource_hash(resource,
      Hash[resource.parameters.map do |name, value|
        value_to_validate = sensitives.include?(name) ? Puppet::Pops::Types::PSensitiveType::Sensitive.new(value.value) : value.value
        [name.to_s, value_to_validate]
      end
    ])
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
        raise Puppet::DevError, _("Parameter '%{name}' is given a type, but is not a valid parameter.") % { name: name }
      end
      unless t.is_a? Puppet::Pops::Types::PAnyType
        raise Puppet::DevError, _("Parameter '%{name}' is given a type that is not a Puppet Type, got %{class_name}") % { name: name, class_name: t.class }
      end

      @argument_types[name] = t
    end
  end

  private

  def convert_from_ast(name)
    value = name.value
    if value.is_a?(Puppet::Parser::AST::Regex)
      value.value
    else
      value
    end
  end

  def evaluate_parent_type(resource)
    klass = parent_type(resource.scope)
    parent_resource = resource.scope.compiler.catalog.resource(:class, klass.name) || resource.scope.compiler.catalog.resource(:node, klass.name) if klass
    return unless klass && parent_resource

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
    scope.class_scope(klass) || raise(Puppet::DevError, _("Could not find scope for %{class_name}") % { class_name: klass.name })
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
      @namespace, _ = @type == :hostclass ? [@name, ''] : namesplit(@name)
    end
  end

  def warn_if_metaparam(param, default)
    return unless Puppet::Type.metaparamclass(param)

    if default
      warnonce _("%{param} is a metaparam; this value will inherit to all contained resources in the %{name} definition") % { param: param, name: self.name }
    else
      raise Puppet::ParseError, _("%{param} is a metaparameter; please choose another parameter name in the %{name} definition") % { param: param, name: self.name }
    end
  end

  def parameter_struct
    @parameter_struct ||= create_params_struct
  end

  def create_params_struct
    arg_types = argument_types
    type_factory = Puppet::Pops::Types::TypeFactory
    members = { type_factory.optional(type_factory.string(NAME)) =>  type_factory.any }

    Puppet::Type.eachmetaparam do |name|
      # TODO: Once meta parameters are typed, this should change to reflect that type
      members[name.to_s] = type_factory.any
    end

    arguments.each_pair do |name, default|
      key_type = type_factory.string(name.to_s)
      key_type = type_factory.optional(key_type) unless default.nil?

      arg_type = arg_types[name]
      arg_type = type_factory.any if arg_type.nil?
      members[key_type] = arg_type
    end
    type_factory.struct(members)
  end
  private :create_params_struct
end
