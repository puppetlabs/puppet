require 'puppet/parser'
require 'puppet/util/warnings'
require 'puppet/util/errors'
require 'puppet/util/inline_docs'
require 'puppet/parser/ast/leaf'
require 'puppet/parser/ast/block_expression'
require 'puppet/dsl'

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
  include Puppet::Util::InlineDocs
  include Puppet::Util::Warnings
  include Puppet::Util::Errors

  RESOURCE_KINDS = [:hostclass, :node, :definition]

  # Map the names used in our documentation to the names used internally
  RESOURCE_KINDS_TO_EXTERNAL_NAMES = {
      :hostclass => "class",
      :node => "node",
      :definition => "defined_type",
  }
  RESOURCE_EXTERNAL_NAMES_TO_KINDS = RESOURCE_KINDS_TO_EXTERNAL_NAMES.invert

  attr_accessor :file, :line, :doc, :code, :ruby_code, :parent, :resource_type_collection
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

  require 'puppet/indirector'
  extend Puppet::Indirector
  indirects :resource_type, :terminus_class => :parser

  def self.from_data_hash(data)
    name = data.delete('name') or raise ArgumentError, "Resource Type names must be specified"
    kind = data.delete('kind') || "definition"

    unless type = RESOURCE_EXTERNAL_NAMES_TO_KINDS[kind]
      raise ArgumentError, "Unsupported resource kind '#{kind}'"
    end

    data = data.inject({}) { |result, ary| result[ary[0].intern] = ary[1]; result }

    # External documentation uses "parameters" but the internal name
    # is "arguments"
    data[:arguments] = data.delete(:parameters)

    new(type, name, data)
  end

  def self.from_pson(data)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(data)
  end

  def to_data_hash
    data = [:doc, :line, :file, :parent].inject({}) do |hash, param|
      next hash unless (value = self.send(param)) and (value != "")
      hash[param.to_s] = value
      hash
    end

    # External documentation uses "parameters" but the internal name
    # is "arguments"
    data['parameters'] = arguments.dup unless arguments.empty?

    data['name'] = name

    unless RESOURCE_KINDS_TO_EXTERNAL_NAMES.has_key?(type)
      raise ArgumentError, "Unsupported resource kind '#{type}'"
    end
    data['kind'] = RESOURCE_KINDS_TO_EXTERNAL_NAMES[type]
    data
  end

  # Are we a child of the passed class?  Do a recursive search up our
  # parentage tree to figure it out.
  def child_of?(klass)
    return false unless parent

    return(klass == parent_type ? true : parent_type.child_of?(klass))
  end

  # Now evaluate the code associated with this class or definition.
  def evaluate_code(resource)

    static_parent = evaluate_parent_type(resource)
    scope = static_parent || resource.scope

    scope = scope.newscope(:namespace => namespace, :source => self, :resource => resource) unless resource.title == :main
    scope.compiler.add_class(name) unless definition?

    set_resource_parameters(resource, scope)

    resource.add_edge_to_stage

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

    evaluate_ruby_code(resource, scope) if ruby_code
  end

  def initialize(type, name, options = {})
    @type = type.to_s.downcase.to_sym
    raise ArgumentError, "Invalid resource supertype '#{type}'" unless RESOURCE_KINDS.include?(@type)

    name = convert_from_ast(name) if name.is_a?(Puppet::Parser::AST::HostName)

    set_name_and_namespace(name)

    [:code, :doc, :line, :file, :parent].each do |param|
      next unless value = options[param]
      send(param.to_s + "=", value)
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
#    self.code = self.code.sequence_with(other.code)
  end

  # Make an instance of the resource type, and place it in the catalog
  # if it isn't in the catalog already.  This is only possible for
  # classes and nodes.  No parameters are be supplied--if this is a
  # parameterized class, then all parameters take on their default
  # values.
  def ensure_in_catalog(scope, parameters=nil)
    type == :definition and raise ArgumentError, "Cannot create resources for defined resource types"
    resource_type = type == :hostclass ? :class : :node

    # Do nothing if the resource already exists; this makes sure we don't
    # get multiple copies of the class resource, which helps provide the
    # singleton nature of classes.
    # we should not do this for classes with parameters
    # if parameters are passed, we should still try to create the resource
    # even if it exists so that we can fail
    # this prevents us from being able to combine param classes with include
    if resource = scope.catalog.resource(resource_type, name) and !parameters
      return resource
    end
    resource = Puppet::Parser::Resource.new(resource_type, name, :scope => scope, :source => self)
    assign_parameter_values(parameters, resource)
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
    return @name unless @name.is_a?(Regexp)
    @name.source.downcase.gsub(/[^-\w:.]/,'').sub(/^\.+/,'')
  end

  def name_is_regex?
    @name.is_a?(Regexp)
  end

  def assign_parameter_values(parameters, resource)
    return unless parameters

    # It'd be nice to assign default parameter values here,
    # but we can't because they often rely on local variables
    # created during set_resource_parameters.
    parameters.each do |name, value|
      resource.set_parameter name, value
    end
  end

  # MQR TODO:
  #
  # The change(s) introduced by the fix for #4270 are mostly silly & should be
  # removed, though we didn't realize it at the time.  If it can be established/
  # ensured that nodes never call parent_type and that resource_types are always
  # (as they should be) members of exactly one resource_type_collection the
  # following method could / should be replaced with:
  #
  # def parent_type
  #   @parent_type ||= parent && (
  #     resource_type_collection.find_or_load([name],parent,type.to_sym) ||
  #     fail Puppet::ParseError, "Could not find parent resource type '#{parent}' of type #{type} in #{resource_type_collection.environment}"
  #   )
  # end
  #
  # ...and then the rest of the changes around passing in scope reverted.
  #
  def parent_type(scope = nil)
    return nil unless parent

    unless @parent_type
      raise "Must pass scope to parent_type when called first time" unless scope
      unless @parent_type = scope.environment.known_resource_types.send("find_#{type}", [name], parent)
        fail Puppet::ParseError, "Could not find parent resource type '#{parent}' of type #{type} in #{scope.environment}"
      end
    end

    @parent_type
  end

  # Set any arguments passed by the resource as variables in the scope.
  def set_resource_parameters(resource, scope)
    set = {}
    resource.to_hash.each do |param, value|
      param = param.to_sym
      fail Puppet::ParseError, "#{resource.ref} does not accept attribute #{param}" unless valid_parameter?(param)

      exceptwrap { scope[param.to_s] = value }

      set[param] = true
    end

    if @type == :hostclass
      scope["title"] = resource.title.to_s.downcase unless set.include? :title
      scope["name"] =  resource.name.to_s.downcase  unless set.include? :name
    else
      scope["title"] = resource.title               unless set.include? :title
      scope["name"] =  resource.name                unless set.include? :name
    end
    scope["module_name"] = module_name if module_name and ! set.include? :module_name

    if caller_name = scope.parent_module_name and ! set.include?(:caller_module_name)
      scope["caller_module_name"] = caller_name
    end
    scope.class_set(self.name,scope) if hostclass? or node?

    # Evaluate the default parameters, now that all other variables are set
    default_params = resource.set_default_parameters(scope)
    default_params.each { |param| scope[param] = resource[param] }

    # This has to come after the above parameters so that default values
    # can use their values
    resource.validate_complete
  end

  # Check whether a given argument is valid.
  def valid_parameter?(param)
    param = param.to_s

    return true if param == "name"
    return true if Puppet::Type.metaparam?(param)
    return false unless defined?(@arguments)
    return(arguments.include?(param) ? true : false)
  end

  def set_arguments(arguments)
    @arguments = {}
    return if arguments.nil?

    arguments.each do |arg, default|
      arg = arg.to_s
      warn_if_metaparam(arg, default)
      @arguments[arg] = default
    end
  end

  # Sets the argument name to Puppet Type hash used for type checking.
  # Names must correspond to available arguments (they must be defined first).
  # Arguments not mentioned will not be type-checked. Only supported when parser == "future"
  #
  def set_argument_types(name_to_type_hash)
    @argument_types = {}
    # Stop here if not running under future parser, the rest requires pops to be initialized
    # and that the type system is available
    return unless Puppet.future_parser? && name_to_type_hash
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

  def evaluate_ruby_code(resource, scope)
    Puppet::DSL::ResourceAPI.new(resource, scope, ruby_code).evaluate
  end

  # Split an fq name into a namespace and name
  def namesplit(fullname)
    ary = fullname.split("::")
    n = ary.pop || ""
    ns = ary.join("::")
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
end
