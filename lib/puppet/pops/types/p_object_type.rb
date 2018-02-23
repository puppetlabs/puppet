require_relative 'ruby_generator'
require_relative 'type_with_members'

module Puppet::Pops
module Types

KEY_ATTRIBUTES = 'attributes'.freeze
KEY_CHECKS = 'checks'.freeze
KEY_CONSTANTS = 'constants'.freeze
KEY_EQUALITY = 'equality'.freeze
KEY_EQUALITY_INCLUDE_TYPE = 'equality_include_type'.freeze
KEY_FINAL = 'final'.freeze
KEY_FUNCTIONS = 'functions'.freeze
KEY_KIND = 'kind'.freeze
KEY_OVERRIDE = 'override'.freeze
KEY_PARENT = 'parent'.freeze
KEY_TYPE_PARAMETERS = 'type_parameters'.freeze

# @api public
class PObjectType < PMetaType
  include TypeWithMembers

  ATTRIBUTE_KIND_CONSTANT = 'constant'.freeze
  ATTRIBUTE_KIND_DERIVED = 'derived'.freeze
  ATTRIBUTE_KIND_GIVEN_OR_DERIVED = 'given_or_derived'.freeze
  ATTRIBUTE_KIND_REFERENCE = 'reference'.freeze
  TYPE_ATTRIBUTE_KIND = TypeFactory.enum(ATTRIBUTE_KIND_CONSTANT, ATTRIBUTE_KIND_DERIVED, ATTRIBUTE_KIND_GIVEN_OR_DERIVED, ATTRIBUTE_KIND_REFERENCE)

  TYPE_OBJECT_NAME = Pcore::TYPE_QUALIFIED_REFERENCE

  TYPE_ATTRIBUTE = TypeFactory.struct({
    KEY_TYPE => PTypeType::DEFAULT,
    TypeFactory.optional(KEY_FINAL) => PBooleanType::DEFAULT,
    TypeFactory.optional(KEY_OVERRIDE) => PBooleanType::DEFAULT,
    TypeFactory.optional(KEY_KIND) => TYPE_ATTRIBUTE_KIND,
    KEY_VALUE => PAnyType::DEFAULT,
    TypeFactory.optional(KEY_ANNOTATIONS) => TYPE_ANNOTATIONS
  })

  TYPE_PARAMETER = TypeFactory.struct({
    KEY_TYPE => PTypeType::DEFAULT,
    TypeFactory.optional(KEY_ANNOTATIONS) => TYPE_ANNOTATIONS
  })

  TYPE_CONSTANTS = TypeFactory.hash_kv(Pcore::TYPE_MEMBER_NAME, PAnyType::DEFAULT)
  TYPE_ATTRIBUTES = TypeFactory.hash_kv(Pcore::TYPE_MEMBER_NAME, TypeFactory.not_undef)
  TYPE_PARAMETERS = TypeFactory.hash_kv(Pcore::TYPE_MEMBER_NAME, TypeFactory.not_undef)
  TYPE_ATTRIBUTE_CALLABLE = TypeFactory.callable(0,0)

  TYPE_FUNCTION_TYPE = PTypeType.new(PCallableType::DEFAULT)

  TYPE_FUNCTION = TypeFactory.struct({
    KEY_TYPE => TYPE_FUNCTION_TYPE,
    TypeFactory.optional(KEY_FINAL) => PBooleanType::DEFAULT,
    TypeFactory.optional(KEY_OVERRIDE) => PBooleanType::DEFAULT,
    TypeFactory.optional(KEY_ANNOTATIONS) => TYPE_ANNOTATIONS
  })
  TYPE_FUNCTIONS = TypeFactory.hash_kv(PVariantType.new([Pcore::TYPE_MEMBER_NAME, PStringType.new('[]')]), TypeFactory.not_undef)

  TYPE_EQUALITY = TypeFactory.variant(Pcore::TYPE_MEMBER_NAME, TypeFactory.array_of(Pcore::TYPE_MEMBER_NAME))

  TYPE_CHECKS = PAnyType::DEFAULT # TBD

  TYPE_OBJECT_I12N = TypeFactory.struct({
    TypeFactory.optional(KEY_NAME) => TYPE_OBJECT_NAME,
    TypeFactory.optional(KEY_PARENT) => PTypeType::DEFAULT,
    TypeFactory.optional(KEY_TYPE_PARAMETERS) => TYPE_PARAMETERS,
    TypeFactory.optional(KEY_ATTRIBUTES) => TYPE_ATTRIBUTES,
    TypeFactory.optional(KEY_CONSTANTS) => TYPE_CONSTANTS,
    TypeFactory.optional(KEY_FUNCTIONS) => TYPE_FUNCTIONS,
    TypeFactory.optional(KEY_EQUALITY) => TYPE_EQUALITY,
    TypeFactory.optional(KEY_EQUALITY_INCLUDE_TYPE) => PBooleanType::DEFAULT,
    TypeFactory.optional(KEY_CHECKS) =>  TYPE_CHECKS,
    TypeFactory.optional(KEY_ANNOTATIONS) => TYPE_ANNOTATIONS
  })

  def self.register_ptype(loader, ir)
    type = create_ptype(loader, ir, 'AnyType', '_pcore_init_hash' => TYPE_OBJECT_I12N)

    # Now, when the Object type exists, add annotations with keys derived from Annotation and freeze the types.
    annotations = TypeFactory.optional(PHashType.new(PTypeType.new(Annotation._pcore_type), TypeFactory.hash_kv(Pcore::TYPE_MEMBER_NAME, PAnyType::DEFAULT)))
    TYPE_ATTRIBUTE.hashed_elements[KEY_ANNOTATIONS].replace_value_type(annotations)
    TYPE_FUNCTION.hashed_elements[KEY_ANNOTATIONS].replace_value_type(annotations)
    TYPE_OBJECT_I12N.hashed_elements[KEY_ANNOTATIONS].replace_value_type(annotations)
    PTypeSetType::TYPE_TYPESET_I12N.hashed_elements[KEY_ANNOTATIONS].replace_value_type(annotations)
    PTypeSetType::TYPE_TYPE_REFERENCE_I12N.hashed_elements[KEY_ANNOTATIONS].replace_value_type(annotations)
    type
  end

  # @abstract Encapsulates behavior common to {PAttribute} and {PFunction}
  # @api public
  class PAnnotatedMember
    include Annotatable
    include InvocableMember

    # @return [PObjectType] the object type containing this member
    # @api public
    attr_reader :container

    # @return [String] the name of this member
    # @api public
    attr_reader :name

    # @return [PAnyType] the type of this member
    # @api public
    attr_reader :type

    # @param name [String] The name of the member
    # @param container [PObjectType] The containing object type
    # @param init_hash [Hash{String=>Object}] Hash containing feature options
    # @option init_hash [PAnyType] 'type' The member type (required)
    # @option init_hash [Boolean] 'override' `true` if this feature must override an inherited feature. Default is `false`.
    # @option init_hash [Boolean] 'final' `true` if this feature cannot be overridden. Default is `false`.
    # @option init_hash [Hash{PTypeType => Hash}] 'annotations' Annotations hash. Default is `nil`.
    # @api public
    def initialize(name, container, init_hash)
      @name = name
      @container = container
      @type = init_hash[KEY_TYPE]
      @override = init_hash[KEY_OVERRIDE]
      @override = false if @override.nil?
      @final = init_hash[KEY_FINAL]
      @final = false if @final.nil?
      init_annotatable(init_hash)
    end

    # Delegates to the contained type
    # @param visitor [TypeAcceptor] the visitor
    # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
    # @api public
    def accept(visitor, guard)
      annotatable_accept(visitor, guard)
      @type.accept(visitor, guard)
    end

    # Checks if the this _member_ overrides an inherited member, and if so, that this member is declared with override = true and that
    # the inherited member accepts to be overridden by this member.
    #
    # @param parent_members [Hash{String=>PAnnotatedMember}] the hash of inherited members
    # @return [PAnnotatedMember] this instance
    # @raises [Puppet::ParseError] if the assertion fails
    # @api private
    def assert_override(parent_members)
      parent_member = parent_members[@name]
      if parent_member.nil?
        if @override
          raise Puppet::ParseError, _("expected %{label} to override an inherited %{feature_type}, but no such %{feature_type} was found") %
              { label: label, feature_type: feature_type }
        end
        self
      else
        parent_member.assert_can_be_overridden(self)
      end
    end

    # Checks if the given _member_ can override this member.
    #
    # @param member [PAnnotatedMember] the overriding member
    # @return [PAnnotatedMember] its argument
    # @raises [Puppet::ParseError] if the assertion fails
    # @api private
    def assert_can_be_overridden(member)
      unless self.class == member.class
        raise Puppet::ParseError, _("%{member} attempts to override %{label}") % { member: member.label, label: label }
      end
      if @final && !(constant? && member.constant?)
        raise Puppet::ParseError, _("%{member} attempts to override final %{label}") % { member: member.label, label: label }
      end
      unless member.override?
        #TRANSLATOR 'override => true' is a puppet syntax and should not be translated
        raise Puppet::ParseError, _("%{member} attempts to override %{label} without having override => true") % { member: member.label, label: label }
      end
      unless @type.assignable?(member.type)
        raise Puppet::ParseError, _("%{member} attempts to override %{label} with a type that does not match") % { member: member.label, label: label }
      end
      member
    end

    def constant?
      false
    end

    # @return [Boolean] `true` if this feature cannot be overridden
    # @api public
    def final?
      @final
    end

    # @return [Boolean] `true` if this feature must override an inherited feature
    # @api public
    def override?
      @override
    end

    # @api public
    def hash
      @name.hash ^ @type.hash
    end

    # @api public
    def eql?(o)
      self.class == o.class && @name == o.name && @type == o.type && @override == o.override? && @final == o.final?
    end

    # @api public
    def ==(o)
      eql?(o)
    end

    # Returns the member as a hash suitable as an argument for constructor. Name is excluded
    # @return [Hash{String=>Object}] the initialization hash
    # @api private
    def _pcore_init_hash
      hash = { KEY_TYPE => @type }
      hash[KEY_FINAL] = true if @final
      hash[KEY_OVERRIDE] = true if @override
      hash[KEY_ANNOTATIONS] = @annotations unless @annotations.nil?
      hash
    end

    # @api private
    def feature_type
      self.class.feature_type
    end

    # @api private
    def label
      self.class.label(@container, @name)
    end

    # Performs type checking of arguments and invokes the method that corresponds to this
    # method. The result of the invocation is returned
    #
    # @param receiver [Object] The receiver of the call
    # @param scope [Puppet::Parser::Scope] The caller scope
    # @param args [Array] Array of arguments.
    # @return [Object] The result returned by the member function or attribute
    #
    # @api private
    def invoke(receiver, scope, args, &block)
      @dispatch ||= create_dispatch(receiver)

      args_type = TypeCalculator.infer_set(block_given? ? args + [block] : args)
      found = @dispatch.find { |d| d.type.callable?(args_type) }
      raise ArgumentError, TypeMismatchDescriber.describe_signatures(label, @dispatch, args_type) if found.nil?
      found.invoke(receiver, scope, args, &block)
    end

    # @api private
    def create_dispatch(instance)
      # TODO: Assumes Ruby implementation for now
      if(callable_type.is_a?(PVariantType))
        callable_type.types.map do |ct|
          Functions::Dispatch.new(ct, RubyGenerator.protect_reserved_name(name), [], false, ct.block_type.nil? ? nil : 'block')
        end
      else
        [Functions::Dispatch.new(callable_type, RubyGenerator.protect_reserved_name(name), [], false, callable_type.block_type.nil? ? nil : 'block')]
      end
    end

    # @api private
    def self.feature_type
      raise NotImplementedError, "'#{self.class.name}' should implement #feature_type"
    end

    def self.label(container, name)
      "#{feature_type} #{container.label}[#{name}]"
    end
  end

  # Describes a named Attribute in an Object type
  # @api public
  class PAttribute < PAnnotatedMember

    # @return [String,nil] The attribute kind as defined by #TYPE_ATTRIBUTE_KIND, or `nil`
    attr_reader :kind

    # @param name [String] The name of the attribute
    # @param container [PObjectType] The containing object type
    # @param init_hash [Hash{String=>Object}] Hash containing attribute options
    # @option init_hash [PAnyType] 'type' The attribute type (required)
    # @option init_hash [Object] 'value' The default value, must be an instanceof the given `type` (optional)
    # @option init_hash [String] 'kind' The attribute kind, matching #TYPE_ATTRIBUTE_KIND
    # @api public
    def initialize(name, container, init_hash)
      super(name, container, TypeAsserter.assert_instance_of(nil, TYPE_ATTRIBUTE, init_hash) { "initializer for #{self.class.label(container, name)}" })
      @kind = init_hash[KEY_KIND]
      if @kind == ATTRIBUTE_KIND_CONSTANT # final is implied
        if init_hash.include?(KEY_FINAL) && !@final
          #TRANSLATOR 'final => false' is puppet syntax and should not be translated
          raise Puppet::ParseError, _("%{label} of kind 'constant' cannot be combined with final => false") % { label: label }
        end
        @final = true
      end

      if init_hash.include?(KEY_VALUE)
        if @kind == ATTRIBUTE_KIND_DERIVED || @kind == ATTRIBUTE_KIND_GIVEN_OR_DERIVED
          raise Puppet::ParseError, _("%{label} of kind '%{kind}' cannot be combined with an attribute value") % { label: label, kind: @kind }
        end
        v = init_hash[KEY_VALUE]
        @value = v == :default ? v : TypeAsserter.assert_instance_of(nil, type, v) {"#{label} #{KEY_VALUE}" }
      else
        raise Puppet::ParseError, _("%{label} of kind 'constant' requires a value") % { label: label } if @kind == ATTRIBUTE_KIND_CONSTANT
        @value = :undef # Not to be confused with nil or :default
      end
    end

    def callable_type
      TYPE_ATTRIBUTE_CALLABLE
    end

    # @api public
    def eql?(o)
      super && @kind == o.kind && @value == (o.value? ? o.value : :undef)
    end

    # Returns the member as a hash suitable as an argument for constructor. Name is excluded
    # @return [Hash{String=>Object}] the hash
    # @api private
    def _pcore_init_hash
      hash = super
      unless @kind.nil?
        hash[KEY_KIND] = @kind
        hash.delete(KEY_FINAL) if @kind == ATTRIBUTE_KIND_CONSTANT # final is implied
      end
      hash[KEY_VALUE] = @value unless @value == :undef
      hash
    end

    def constant?
      @kind == ATTRIBUTE_KIND_CONSTANT
    end

    # @return [Booelan] true if the given value equals the default value for this attribute
    def default_value?(value)
      @value == value
    end

    # @return [Boolean] `true` if a value has been defined for this attribute.
    def value?
      @value != :undef
    end

    # Returns the value of this attribute, or raises an error if no value has been defined. Raising an error
    # is necessary since a defined value may be `nil`.
    #
    # @return [Object] the value that has been defined for this attribute.
    # @raise [Puppet::Error] if no value has been defined
    # @api public
    def value
      # An error must be raised here since `nil` is a valid value and it would be bad to leak the :undef symbol
      raise Puppet::Error, "#{label} has no value" if @value == :undef
      @value
    end

    # @api private
    def self.feature_type
      'attribute'
    end
  end

  class PTypeParameter < PAttribute
    # @return [Hash{String=>Object}] the hash
    # @api private
    def _pcore_init_hash
      hash = super
      hash[KEY_TYPE] = hash[KEY_TYPE].type
      hash.delete(KEY_VALUE) if hash.include?(KEY_VALUE) && hash[KEY_VALUE].nil?
      hash
    end

    # @api private
    def self.feature_type
      'type_parameter'
    end
  end

  # Describes a named Function in an Object type
  # @api public
  class PFunction < PAnnotatedMember

    # @param name [String] The name of the attribute
    # @param container [PObjectType] The containing object type
    # @param init_hash [Hash{String=>Object}] Hash containing function options
    # @api public
    def initialize(name, container, init_hash)
      super(name, container, TypeAsserter.assert_instance_of(["initializer for function '%s'", name], TYPE_FUNCTION, init_hash))
    end

    def callable_type
      type
    end

    # @api private
    def self.feature_type
      'function'
    end
  end

  attr_reader :name
  attr_reader :parent
  attr_reader :equality
  attr_reader :checks
  attr_reader :annotations

  # Initialize an Object Type instance. The initialization will use either a name and an initialization
  # hash expression, or a fully resolved initialization hash.
  #
  # @overload initialize(name, init_hash_expression)
  #   Used when the Object type is loaded using a type alias expression. When that happens, it is important that
  #   the actual resolution of the expression is deferred until all definitions have been made known to the current
  #   loader. The object will then be resolved when it is loaded by the {TypeParser}. "resolved" here, means that
  #   the hash expression is fully resolved, and then passed to the {#_pcore_init_from_hash} method.
  #   @param name [String] The name of the object
  #   @param init_hash_expression [Model::LiteralHash] The hash describing the Object features
  #
  # @overload initialize(init_hash)
  #   Used when the object is created by the {TypeFactory}. The init_hash must be fully resolved.
  #   @param _pcore_init_hash [Hash{String=>Object}] The hash describing the Object features
  #   @param loader [Loaders::Loader,nil] the loader that loaded the type
  #
  # @api private
  def initialize(_pcore_init_hash, init_hash_expression = nil)
    if _pcore_init_hash.is_a?(Hash)
      _pcore_init_from_hash(_pcore_init_hash)
      @loader = init_hash_expression unless init_hash_expression.nil?
    else
      @type_parameters = EMPTY_HASH
      @attributes = EMPTY_HASH
      @functions = EMPTY_HASH
      @name = TypeAsserter.assert_instance_of('object name', TYPE_OBJECT_NAME, _pcore_init_hash)
      @init_hash_expression = init_hash_expression
    end
  end

  def instance?(o, guard = nil)
    if o.is_a?(PuppetObject)
      assignable?(o._pcore_type, guard)
    else
      name = o.class.name
      return false if name.nil? # anonymous class that doesn't implement PuppetObject is not an instance
      ir = Loaders.implementation_registry
      type = ir.nil? ? nil : ir.type_for_module(name)
      !type.nil? && assignable?(type, guard)
    end
  end

  # @api private
  def new_function
    @new_function ||= create_new_function
  end

  # Assign a new instance reader to this type
  # @param [Serialization::InstanceReader] reader the reader to assign
  # @api private
  def reader=(reader)
    @reader = reader
  end

  # Assign a new instance write to this type
  # @param [Serialization::InstanceWriter] the writer to assign
  # @api private
  def writer=(writer)
    @writer = writer
  end

  # Read an instance of this type from a deserializer
  # @param [Integer] value_count the number attributes needed to create the instance
  # @param [Serialization::Deserializer] deserializer the deserializer to read from
  # @return [Object] the created instance
  # @api private
  def read(value_count, deserializer)
    reader.read(self, implementation_class, value_count, deserializer)
  end

  # Write an instance of this type using a serializer
  # @param [Object] value the instance to write
  # @param [Serialization::Serializer] the serializer to write to
  # @api private
  def write(value, serializer)
    writer.write(self, value, serializer)
  end

    # @api private
  def create_new_function
    impl_class = implementation_class
    return impl_class.create_new_function(self) if impl_class.respond_to?(:create_new_function)

    (param_names, param_types, required_param_count) = parameter_info(impl_class)

    # Create the callable with a size that reflects the required and optional parameters
    create_type = TypeFactory.callable(*param_types, required_param_count, param_names.size)
    from_hash_type = TypeFactory.callable(init_hash_type, 1, 1)

    # Create and return a #new_XXX function where the dispatchers are added programmatically.
    Puppet::Functions.create_loaded_function(:"new_#{name}", loader) do

      # The class that creates new instances must be available to the constructor methods
      # and is therefore declared as a variable and accessor on the class that represents
      # this added function.
      @impl_class = impl_class

      def self.impl_class
        @impl_class
      end

      # It's recommended that an implementor of an Object type provides the method #from_asserted_hash.
      # This method should accept a hash and assume that type assertion has been made already (it is made
      # by the dispatch added here).
      if impl_class.respond_to?(:from_asserted_hash)
        dispatcher.add(Functions::Dispatch.new(from_hash_type, :from_hash, ['hash']))
        def from_hash(hash)
          self.class.impl_class.from_asserted_hash(hash)
        end
      end

      # Add the dispatch that uses the standard #from_asserted_args or #new method on the class. It's assumed that the
      # method performs no assertions.
      dispatcher.add(Functions::Dispatch.new(create_type, :create, param_names))
      if impl_class.respond_to?(:from_asserted_args)
        def create(*args)
          self.class.impl_class.from_asserted_args(*args)
        end
      else
        def create(*args)
          self.class.impl_class.new(*args)
        end
      end
    end
  end

  # @api private
  def implementation_class(create = true)
    if @implementation_class.nil? && create
      ir = Loaders.implementation_registry
      class_name = ir.nil? ? nil : ir.module_name_for_type(self)
      if class_name.nil?
        # Use generator to create a default implementation
        @implementation_class = RubyGenerator.new.create_class(self)
        @implementation_class.class_eval(&@implementation_override) if instance_variable_defined?(:@implementation_override)
      else
        # Can the mapping be loaded?
        @implementation_class = ClassLoader.provide(class_name)

        raise Puppet::Error, "Unable to load class #{class_name}" if @implementation_class.nil?
        unless @implementation_class < PuppetObject || @implementation_class.respond_to?(:ecore)
          raise Puppet::Error, "Unable to create an instance of #{name}. #{class_name} does not include module #{PuppetObject.name}"
        end
      end
    end
    @implementation_class
  end

  # @api private
  def implementation_class=(cls)
    raise ArgumentError, "attempt to redefine implementation class for #{label}" unless @implementation_class.nil?
    @implementation_class = cls
  end

  # The block passed to this method will be passed in a call to `#class_eval` on the dynamically generated
  # class for this data type. It's indended use is to complement or redefine the generated methods and
  # attribute readers.
  #
  # The method is normally called with the block passed to `#implementation` when a data type is defined using
  # {Puppet::DataTypes::create_type}.
  #
  # @api private
  def implementation_override=(block)
    if !@implementation_class.nil? || instance_variable_defined?(:@implementation_override)
      raise ArgumentError, "attempt to redefine implementation override for #{label}"
    end
    @implementation_override = block
  end

  def extract_init_hash(o)
    return o._pcore_init_hash if o.respond_to?(:_pcore_init_hash)

    result = {}
    pic = parameter_info(o.class)
    attrs = attributes(true)
    pic[0].each do |name|
      v = o.send(name)
      result[name] = v unless attrs[name].default_value?(v)
    end
    result
  end

  # @api private
  # @return [(Array<String>, Array<PAnyType>, Integer)] array of parameter names, array of parameter types, and a count reflecting the required number of parameters
  def parameter_info(impl_class)
    # Create a types and a names array where optional entries ends up last
    @parameter_info ||= {}
    pic = @parameter_info[impl_class]
    return pic if pic

    opt_types = []
    opt_names = []
    non_opt_types = []
    non_opt_names = []
    init_hash_type.elements.each do |se|
      if se.key_type.is_a?(POptionalType)
        opt_names << se.name
        opt_types << se.value_type
      else
        non_opt_names << se.name
        non_opt_types << se.value_type
      end
    end
    param_names = non_opt_names + opt_names
    param_types = non_opt_types + opt_types
    param_count = param_names.size

    init = impl_class.respond_to?(:from_asserted_args) ? impl_class.method(:from_asserted_args) : impl_class.instance_method(:initialize)
    init_non_opt_count = 0
    init_param_names = init.parameters.map do |p|
      init_non_opt_count += 1 if :req == p[0]
      n = p[1].to_s
      r = RubyGenerator.unprotect_reserved_name(n)
      unless r.equal?(n)
        # assert that the protected name wasn't a real name (names can start with underscore)
        n = r unless param_names.index(r).nil?
      end
      n
    end

    if init_param_names != param_names
      if init_param_names.size < param_count || init_non_opt_count > param_count
        raise Serialization::SerializationError, "Initializer for class #{impl_class.name} does not match the attributes of #{name}"
      end
      init_param_names = init_param_names[0, param_count] if init_param_names.size > param_count
      unless init_param_names == param_names
        # Reorder needed to match initialize method arguments
        new_param_types = []
        init_param_names.each do |ip|
          index = param_names.index(ip)
          if index.nil?
            raise Serialization::SerializationError,
              "Initializer for class #{impl_class.name} parameter '#{ip}' does not match any of the the attributes of type #{name}"
          end
          new_param_types << param_types[index]
        end
        param_names = init_param_names
        param_types = new_param_types
      end
    end

    pic = [param_names.freeze, param_types.freeze, non_opt_types.size].freeze
    @parameter_info[impl_class] = pic
    pic
  end

  # @api private
  def attr_reader_name(se)
    if se.value_type.is_a?(PBooleanType) || se.value_type.is_a?(POptionalType) && se.value_type.type.is_a?(PBooleanType)
      "#{se.name}?"
    else
      se.name
    end
  end

  def self.from_hash(hash)
    new(hash, nil)
  end

  # @api private
  def _pcore_init_from_hash(init_hash)
    TypeAsserter.assert_instance_of('object initializer', TYPE_OBJECT_I12N, init_hash)
    @type_parameters = EMPTY_HASH
    @attributes = EMPTY_HASH
    @functions = EMPTY_HASH

    # Name given to the loader have higher precedence than a name declared in the type
    @name ||= init_hash[KEY_NAME]
    @name.freeze unless @name.nil?

    @parent = init_hash[KEY_PARENT]

    parent_members = EMPTY_HASH
    parent_type_params = EMPTY_HASH
    parent_object_type = nil
    unless @parent.nil?
      check_self_recursion(self)
      rp = resolved_parent
      raise Puppet::ParseError, _("reference to unresolved type '%{name}'") % { :name => rp.type_string } if rp.is_a?(PTypeReferenceType)
      if rp.is_a?(PObjectType)
        parent_object_type = rp
        parent_members = rp.members(true)
        parent_type_params = rp.type_parameters(true)
      end
    end

    type_parameters = init_hash[KEY_TYPE_PARAMETERS]
    unless type_parameters.nil? || type_parameters.empty?
      @type_parameters = {}
      type_parameters.each do |key, param_spec|
        param_value = :undef
        if param_spec.is_a?(Hash)
          param_type = param_spec[KEY_TYPE]
          param_value = param_spec[KEY_VALUE] if param_spec.include?(KEY_VALUE)
        else
          param_type = TypeAsserter.assert_instance_of(nil, PTypeType::DEFAULT, param_spec) { "type_parameter #{label}[#{key}]" }
        end
        param_type = POptionalType.new(param_type) unless param_type.is_a?(POptionalType)
        type_param = PTypeParameter.new(key, self, KEY_TYPE => param_type, KEY_VALUE => param_value).assert_override(parent_type_params)
        @type_parameters[key] = type_param
      end
    end

    constants = init_hash[KEY_CONSTANTS]
    attr_specs = init_hash[KEY_ATTRIBUTES]
    if attr_specs.nil?
      attr_specs = {}
    else
      # attr_specs might be frozen
      attr_specs = Hash[attr_specs]
    end
    unless constants.nil? || constants.empty?
      constants.each do |key, value|
        if attr_specs.include?(key)
          raise Puppet::ParseError, _("attribute %{label}[%{key}] is defined as both a constant and an attribute") % { label: label, key: key }
        end
        attr_spec = {
          # Type must be generic here, or overrides would become impossible
          KEY_TYPE => TypeCalculator.infer(value).generalize,
          KEY_VALUE => value,
          KEY_KIND => ATTRIBUTE_KIND_CONSTANT
        }
        # Indicate override if parent member exists. Type check etc. will take place later on.
        attr_spec[KEY_OVERRIDE] = parent_members.include?(key)
        attr_specs[key] = attr_spec
      end
    end

    unless attr_specs.empty?
      @attributes = Hash[attr_specs.map do |key, attr_spec|
        unless attr_spec.is_a?(Hash)
          attr_type = TypeAsserter.assert_instance_of(nil, PTypeType::DEFAULT, attr_spec) { "attribute #{label}[#{key}]" }
          attr_spec = { KEY_TYPE => attr_type }
          attr_spec[KEY_VALUE] = nil if attr_type.is_a?(POptionalType)
        end
        attr = PAttribute.new(key, self, attr_spec)
        [attr.name, attr.assert_override(parent_members)]
      end].freeze
    end

    func_specs = init_hash[KEY_FUNCTIONS]
    unless func_specs.nil? || func_specs.empty?
      @functions = Hash[func_specs.map do |key, func_spec|
        func_spec = { KEY_TYPE => TypeAsserter.assert_instance_of(nil, TYPE_FUNCTION_TYPE, func_spec) { "function #{label}[#{key}]" } } unless func_spec.is_a?(Hash)
        func = PFunction.new(key, self, func_spec)
        name = func.name
        raise Puppet::ParseError, _("%{label} conflicts with attribute with the same name") % { label: func.label } if @attributes.include?(name)
        [name, func.assert_override(parent_members)]
      end].freeze
    end

    @equality_include_type = init_hash[KEY_EQUALITY_INCLUDE_TYPE]
    @equality_include_type = true if @equality_include_type.nil?

    equality = init_hash[KEY_EQUALITY]
    equality = [equality] if equality.is_a?(String)
    if equality.is_a?(Array)
      unless equality.empty?
        #TRANSLATORS equality_include_type = false should not be translated
        raise Puppet::ParseError, _('equality_include_type = false cannot be combined with non empty equality specification') unless @equality_include_type
        parent_eq_attrs = nil
        equality.each do |attr_name|

          attr = parent_members[attr_name]
          if attr.nil?
            attr = @attributes[attr_name] || @functions[attr_name]
          elsif attr.is_a?(PAttribute)
            # Assert that attribute is not already include by parent equality
            parent_eq_attrs ||= parent_object_type.equality_attributes
            if parent_eq_attrs.include?(attr_name)
              including_parent = find_equality_definer_of(attr)
              raise Puppet::ParseError, _("%{label} equality is referencing %{attribute} which is included in equality of %{including_parent}") %
                  { label: label, attribute: attr.label, including_parent: including_parent.label }
            end
          end

          unless attr.is_a?(PAttribute)
            if attr.nil?
              raise Puppet::ParseError, _("%{label} equality is referencing non existent attribute '%{attribute}'") % { label: label, attribute: attr_name }
            end
            raise Puppet::ParseError, _("%{label} equality is referencing %{attribute}. Only attribute references are allowed") %
                { label: label, attribute: attr.label }
          end
          if attr.kind == ATTRIBUTE_KIND_CONSTANT
            raise Puppet::ParseError, _("%{label} equality is referencing constant %{attribute}.") % { label: label, attribute: attr.label } + ' ' +
                _("Reference to constant is not allowed in equality")
          end
        end
      end
      equality.freeze
    end
    @equality = equality

    @checks = init_hash[KEY_CHECKS]
    init_annotatable(init_hash)
  end

  def [](name)
    member = @attributes[name] || @functions[name]
    if member.nil?
      rp = resolved_parent
      member = rp[name] if rp.is_a?(PObjectType)
    end
    member
  end

  def accept(visitor, guard)
    guarded_recursion(guard, nil) do |g|
      super(visitor, g)
      @parent.accept(visitor, g) unless parent.nil?
      @type_parameters.values.each { |p| p.accept(visitor, g) }
      @attributes.values.each { |a| a.accept(visitor, g) }
      @functions.values.each { |f| f.accept(visitor, g) }
    end
  end

  def callable_args?(callable, guard)
    @parent.nil? ? false : @parent.callable_args?(callable, guard)
  end

  # Returns the type that a initialization hash used for creating instances of this type must conform to.
  #
  # @return [PStructType] the initialization hash type
  # @api public
  def init_hash_type
    @init_hash_type ||= create_init_hash_type
  end

  def allocate
    implementation_class.allocate
  end

  def create(*args)
    implementation_class.create(*args)
  end

  def from_hash(hash)
    implementation_class.from_hash(hash)
  end

  # Creates the type that a initialization hash used for creating instances of this type must conform to.
  #
  # @return [PStructType] the initialization hash type
  # @api private
  def create_init_hash_type
    struct_elems = {}
    attributes(true).values.each do |attr|
      unless attr.kind == ATTRIBUTE_KIND_CONSTANT || attr.kind == ATTRIBUTE_KIND_DERIVED
        if attr.value?
          struct_elems[TypeFactory.optional(attr.name)] = attr.type
        else
          struct_elems[attr.name] = attr.type
        end
      end
    end
    TypeFactory.struct(struct_elems)
  end

  # The init_hash is primarily intended for serialization and string representation purposes. It creates a hash
  # suitable for passing to {PObjectType#new(init_hash)}
  #
  # @return [Hash{String=>Object}] the features hash
  # @api public
  def _pcore_init_hash(include_name = true)
    result = super()
    result[KEY_NAME] = @name if include_name && !@name.nil?
    result[KEY_PARENT] = @parent unless @parent.nil?
    result[KEY_TYPE_PARAMETERS] = compressed_members_hash(@type_parameters) unless @type_parameters.empty?
    unless @attributes.empty?
      # Divide attributes into constants and others
      tc = TypeCalculator.singleton
      constants, others = @attributes.partition do |_, a|
        a.kind == ATTRIBUTE_KIND_CONSTANT && a.type == tc.infer(a.value).generalize
      end.map { |ha| Hash[ha] }

      result[KEY_ATTRIBUTES] = compressed_members_hash(others) unless others.empty?
      unless constants.empty?
        # { kind => 'constant', type => <type of value>, value => <value> } becomes just <value>
        constants.each_pair { |key, a| constants[key] = a.value }
        result[KEY_CONSTANTS] = constants
      end
    end
    result[KEY_FUNCTIONS] = compressed_members_hash(@functions) unless @functions.empty?
    result[KEY_EQUALITY] = @equality unless @equality.nil?
    result[KEY_CHECKS] = @checks unless @checks.nil?
    result
  end

  def eql?(o)
    self.class == o.class &&
      @name == o.name &&
      @parent == o.parent &&
      @type_parameters == o.type_parameters &&
      @attributes == o.attributes &&
      @functions == o.functions &&
      @equality == o.equality &&
      @checks == o.checks
  end

  def hash
    @name.nil? ? [@parent, @type_parameters, @attributes, @functions].hash : @name.hash
  end

  def kind_of_callable?(optional=true, guard = nil)
    @parent.nil? ? false : @parent.kind_of_callable?(optional, guard)
  end

  def iterable?(guard = nil)
    @parent.nil? ? false : @parent.iterable?(guard)
  end

  def iterable_type(guard = nil)
    @parent.nil? ? false : @parent.iterable_type(guard)
  end

  def parameterized?
    if @type_parameters.empty?
      @parent.is_a?(PObjectType) ? @parent.parameterized? : false
    else
      true
    end
  end

  # Returns the members (attributes and functions) of this `Object` type. If _include_parent_ is `true`, then all
  # inherited members will be included in the returned `Hash`.
  #
  # @param include_parent [Boolean] `true` if inherited members should be included
  # @return [Hash{String=>PAnnotatedMember}] a hash with the members
  # @api public
  def members(include_parent = false)
    get_members(include_parent, :both)
  end

  # Returns the attributes of this `Object` type. If _include_parent_ is `true`, then all
  # inherited attributes will be included in the returned `Hash`.
  #
  # @param include_parent [Boolean] `true` if inherited attributes should be included
  # @return [Hash{String=>PAttribute}] a hash with the attributes
  # @api public
  def attributes(include_parent = false)
    get_members(include_parent, :attributes)
  end

  # Returns the attributes that participate in equality comparison. Inherited equality attributes
  # are included.
  # @return [Hash{String=>PAttribute}] a hash of attributes
  # @api public
  def equality_attributes
    all = {}
    collect_equality_attributes(all)
    all
  end

  # @return [Boolean] `true` if this type is included when comparing instances
  # @api public
  def equality_include_type?
    @equality_include_type
  end

  # Returns the functions of this `Object` type. If _include_parent_ is `true`, then all
  # inherited functions will be included in the returned `Hash`.
  #
  # @param include_parent [Boolean] `true` if inherited functions should be included
  # @return [Hash{String=>PFunction}] a hash with the functions
  # @api public
  def functions(include_parent = false)
    get_members(include_parent, :functions)
  end

  DEFAULT = PObjectType.new(EMPTY_HASH)
  # Assert that this type does not inherit from itself
  # @api private
  def check_self_recursion(originator)
    unless @parent.nil?
      raise Puppet::Error, "The Object type '#{originator.label}' inherits from itself" if @parent.equal?(originator)
      @parent.check_self_recursion(originator)
    end
  end

  # @api private
  def label
    @name || 'Object'
  end

  # @api private
  def resolved_parent
    parent = @parent
    while parent.is_a?(PTypeAliasType)
      parent = parent.resolved_type
    end
    parent
  end

  def simple_name
    label.split(DOUBLE_COLON).last
  end

  # Returns the type_parameters of this `Object` type. If _include_parent_ is `true`, then all
  # inherited type_parameters will be included in the returned `Hash`.
  #
  # @param include_parent [Boolean] `true` if inherited type_parameters should be included
  # @return [Hash{String=>PTypeParameter}] a hash with the type_parameters
  # @api public
  def type_parameters(include_parent = false)
    all = {}
    collect_type_parameters(all, include_parent)
    all
  end

  protected

  # An Object type is only assignable from another Object type. The other type
  # or one of its parents must be equal to this type.
  def _assignable?(o, guard)
    if o.is_a?(PObjectType)
      if DEFAULT == self || self == o
        true
      else
        op = o.parent
        op.nil? ? false : assignable?(op, guard)
      end
    elsif o.is_a?(PObjectTypeExtension)
      assignable?(o.base_type, guard)
    else
      false
    end
  end

  def get_members(include_parent, member_type)
    all = {}
    collect_members(all, include_parent, member_type)
    all
  end

  def collect_members(collector, include_parent, member_type)
    if include_parent
      parent = resolved_parent
      parent.collect_members(collector, include_parent, member_type) if parent.is_a?(PObjectType)
    end
    collector.merge!(@attributes) unless member_type == :functions
    collector.merge!(@functions) unless member_type == :attributes
    nil
  end

  def collect_equality_attributes(collector)
    parent = resolved_parent
    parent.collect_equality_attributes(collector) if parent.is_a?(PObjectType)
    if @equality.nil?
      # All attributes except constants participate
      collector.merge!(@attributes.reject { |_, attr| attr.kind == ATTRIBUTE_KIND_CONSTANT })
    else
      collector.merge!(Hash[@equality.map { |attr_name| [attr_name, @attributes[attr_name]] }])
    end
    nil
  end

  def collect_type_parameters(collector, include_parent)
    if include_parent
      parent = resolved_parent
      parent.collect_type_parameters(collector, include_parent) if parent.is_a?(PObjectType)
    end
    collector.merge!(@type_parameters)
    nil
  end

  private

  def compressed_members_hash(features)
    Hash[features.values.map do |feature|
      fh = feature._pcore_init_hash
      if fh.size == 1
        type = fh[KEY_TYPE]
        fh = type unless type.nil?
      end
      [feature.name, fh]
    end]
  end

  # @return [PObjectType] the topmost parent who's #equality_attributes include the given _attr_
  def find_equality_definer_of(attr)
    type = self
    while !type.nil? do
      p = type.resolved_parent
      return type unless p.is_a?(PObjectType)
      return type unless p.equality_attributes.include?(attr.name)
      type = p
    end
    nil
  end

  def guarded_recursion(guard, dflt)
    if @self_recursion
      guard ||= RecursionGuard.new
      guard.with_this(self) { |state| (state & RecursionGuard::SELF_RECURSION_IN_THIS) == 0 ? yield(guard) : dflt }
    else
      yield(guard)
    end
  end

  def reader
    @reader ||= Serialization::ObjectReader::INSTANCE
  end

  def writer
    @writer ||= Serialization::ObjectWriter::INSTANCE
  end
end
end
end
