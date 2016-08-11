require_relative 'ruby_generator'

module Puppet::Pops
module Types

KEY_ATTRIBUTES = 'attributes'.freeze
KEY_CHECKS = 'checks'.freeze
KEY_EQUALITY = 'equality'.freeze
KEY_EQUALITY_INCLUDE_TYPE = 'equality_include_type'.freeze
KEY_FINAL = 'final'.freeze
KEY_FUNCTIONS = 'functions'.freeze
KEY_KIND = 'kind'.freeze
KEY_OVERRIDE = 'override'.freeze
KEY_PARENT = 'parent'.freeze

# @api public
class PObjectType < PMetaType

  ATTRIBUTE_KIND_CONSTANT = 'constant'.freeze
  ATTRIBUTE_KIND_DERIVED = 'derived'.freeze
  ATTRIBUTE_KIND_GIVEN_OR_DERIVED = 'given_or_derived'.freeze
  TYPE_ATTRIBUTE_KIND = TypeFactory.enum(ATTRIBUTE_KIND_CONSTANT, ATTRIBUTE_KIND_DERIVED, ATTRIBUTE_KIND_GIVEN_OR_DERIVED)

  TYPE_OBJECT_NAME = Pcore::TYPE_QUALIFIED_REFERENCE
  TYPE_MEMBER_NAME = PPatternType.new([PRegexpType.new(Patterns::PARAM_NAME)])

  TYPE_ATTRIBUTE = TypeFactory.struct({
    KEY_TYPE => PType::DEFAULT,
    KEY_ANNOTATIONS => TypeFactory.optional(TYPE_ANNOTATIONS),
    KEY_FINAL => TypeFactory.optional(PBooleanType::DEFAULT),
    KEY_OVERRIDE => TypeFactory.optional(PBooleanType::DEFAULT),
    KEY_KIND => TypeFactory.optional(TYPE_ATTRIBUTE_KIND),
    KEY_VALUE => PAnyType::DEFAULT
  })
  TYPE_ATTRIBUTES = TypeFactory.hash_kv(TYPE_MEMBER_NAME, TypeFactory.not_undef)
  TYPE_ATTRIBUTE_CALLABLE = TypeFactory.callable(0,0)

  TYPE_FUNCTION_TYPE = PType.new(PCallableType::DEFAULT)

  TYPE_FUNCTION = TypeFactory.struct({
    KEY_TYPE => TYPE_FUNCTION_TYPE,
    KEY_ANNOTATIONS => TypeFactory.optional(TYPE_ANNOTATIONS),
    KEY_FINAL => TypeFactory.optional(PBooleanType::DEFAULT),
    KEY_OVERRIDE => TypeFactory.optional(PBooleanType::DEFAULT)
  })
  TYPE_FUNCTIONS = TypeFactory.hash_kv(TYPE_MEMBER_NAME, TypeFactory.not_undef)

  TYPE_EQUALITY = TypeFactory.variant(TYPE_MEMBER_NAME, TypeFactory.array_of(TYPE_MEMBER_NAME))

  TYPE_CHECKS = PAnyType::DEFAULT # TBD

  TYPE_OBJECT_I12N = TypeFactory.struct({
    KEY_NAME => TypeFactory.optional(TYPE_OBJECT_NAME),
    KEY_PARENT => TypeFactory.optional(PType::DEFAULT),
    KEY_ATTRIBUTES => TypeFactory.optional(TYPE_ATTRIBUTES),
    KEY_FUNCTIONS => TypeFactory.optional(TYPE_FUNCTIONS),
    KEY_EQUALITY => TypeFactory.optional(TYPE_EQUALITY),
    KEY_EQUALITY_INCLUDE_TYPE => TypeFactory.optional(PBooleanType::DEFAULT),
    KEY_CHECKS =>  TypeFactory.optional(TYPE_CHECKS),
    KEY_ANNOTATIONS =>  TypeFactory.optional(TYPE_ANNOTATIONS)
  })

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType', 'i12n_hash' => TYPE_OBJECT_I12N)
  end

  # @abstract Encapsulates behavior common to {PAttribute} and {PFunction}
  # @api public
  class PAnnotatedMember
    include Annotatable

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
    # @param i12n_hash [Hash{String=>Object}] Hash containing feature options
    # @option i12n_hash [PAnyType] 'type' The member type (required)
    # @option i12n_hash [Boolean] 'override' `true` if this feature must override an inherited feature. Default is `false`.
    # @option i12n_hash [Boolean] 'final' `true` if this feature cannot be overridden. Default is `false`.
    # @option i12n_hash [Hash{PType => Hash}] 'annotations' Annotations hash. Default is `nil`.
    # @api public
    def initialize(name, container, i12n_hash)
      @name = name
      @container = container
      @type = i12n_hash[KEY_TYPE]
      @override = i12n_hash[KEY_OVERRIDE]
      @override = false if @override.nil?
      @final = i12n_hash[KEY_FINAL]
      @final = false if @final.nil?
      init_annotatable(i12n_hash)
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
        raise Puppet::ParseError, "expected #{label} to override an inherited #{feature_type}, but no such #{feature_type} was found" if @override
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
      raise Puppet::ParseError, "#{member.label} attempts to override #{label}" unless self.class == member.class
      raise Puppet::ParseError, "#{member.label} attempts to override final #{label}" if @final
      raise Puppet::ParseError, "#{member.label} attempts to override #{label} without having override => true" unless member.override?
      raise Puppet::ParseError, "#{member.label} attempts to override #{label} with a type that does not match" unless @type.assignable?(member.type)
      member
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
    def i12n_hash
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
      unless @dispatch.type.callable?(args_type)
        raise ArgumentError, TypeMismatchDescriber.describe_signatures(label, [@dispatch], args_type)
      end
      @dispatch.invoke(receiver, scope, args, &block)
    end

    # @api private
    def create_dispatch(instance)
      # TODO: Assumes Ruby implementation for now
      Functions::Dispatch.new(callable_type, name, [],
        callable_type.block_type.nil? ? nil : 'block', nil, nil, false)
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

    # @return [String,nil] The attribute kind as defined by #TYPE_ATTRIBUTE_KIND, or `nil` to
    #   indicate that
    attr_reader :kind

    # @param name [String] The name of the attribute
    # @param container [PObjectType] The containing object type
    # @param i12n_hash [Hash{String=>Object}] Hash containing attribute options
    # @option i12n_hash [PAnyType] 'type' The attribute type (required)
    # @option i12n_hash [Object] 'value' The default value, must be an instanceof the given `type` (optional)
    # @option i12n_hash [String] 'kind' The attribute kind, matching #TYPE_ATTRIBUTE_KIND
    # @api public
    def initialize(name, container, i12n_hash)
      super(name, container, TypeAsserter.assert_instance_of(nil, TYPE_ATTRIBUTE, i12n_hash) { "initializer for #{self.class.label(container, name)}" })
      @kind = i12n_hash[KEY_KIND]
      if @kind == ATTRIBUTE_KIND_CONSTANT # final is implied
        if i12n_hash.include?(KEY_FINAL) && !@final
          raise Puppet::ParseError, "#{label} of kind 'constant' cannot be combined with final => false"
        end
        @final = true
      end

      if i12n_hash.include?(KEY_VALUE)
        if @kind == ATTRIBUTE_KIND_DERIVED || @kind == ATTRIBUTE_KIND_GIVEN_OR_DERIVED
          raise Puppet::ParseError, "#{label} of kind '#{@kind}' cannot be combined with an attribute value"
        end
        v = i12n_hash[KEY_VALUE]
        @value = v == :default ? v : TypeAsserter.assert_instance_of(nil, type, v) {"#{label} #{KEY_VALUE}" }
      else
        raise Puppet::ParseError, "#{label} of kind 'constant' requires a value" if @kind == ATTRIBUTE_KIND_CONSTANT
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
    def i12n_hash
      hash = super
      unless @kind.nil?
        hash[KEY_KIND] = @kind
        hash.delete(KEY_FINAL) if @kind == ATTRIBUTE_KIND_CONSTANT # final is implied
      end
      hash[KEY_VALUE] = @value unless @value == :undef
      hash
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

  # Describes a named Function in an Object type
  # @api public
  class PFunction < PAnnotatedMember

    # @param name [String] The name of the attribute
    # @param container [PObjectType] The containing object type
    # @param i12n_hash [Hash{String=>Object}] Hash containing function options
    # @api public
    def initialize(name, container, i12n_hash)
      super(name, container, TypeAsserter.assert_instance_of(["initializer for function '%s'", name], TYPE_FUNCTION, i12n_hash))
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
  attr_reader :attributes
  attr_reader :functions
  attr_reader :equality
  attr_reader :checks
  attr_reader :annotations

  # Initialize an Object Type instance. The initialization will use either a name and an initialization
  # hash expression, or a fully resolved initialization hash.
  #
  # @overload initialize(name, i12n_hash_expression)
  #   Used when the Object type is loaded using a type alias expression. When that happens, it is important that
  #   the actual resolution of the expression is deferred until all definitions have been made known to the current
  #   loader. The object will then be resolved when it is loaded by the {TypeParser}. "resolved" here, means that
  #   the hash expression is fully resolved, and then passed to the {#initialize_from_hash} method.
  #   @param name [String] The name of the object
  #   @param i12n_hash_expression [Model::LiteralHash] The hash describing the Object features
  #
  # @overload initialize(i12n_hash)
  #   Used when the object is created by the {TypeFactory}. The i12n_hash must be fully resolved.
  #   @param i12n_hash [Hash{String=>Object}] The hash describing the Object features
  #
  # @api private
  def initialize(name_or_i12n_hash, i12n_hash_expression = nil)
    @attributes = EMPTY_HASH
    @functions = EMPTY_HASH

    if name_or_i12n_hash.is_a?(Hash)
      initialize_from_hash(name_or_i12n_hash)
    else
      @name = TypeAsserter.assert_instance_of('object name', TYPE_OBJECT_NAME, name_or_i12n_hash)
      @i12n_hash_expression = i12n_hash_expression
    end
  end

  # @api private
  def new_function(loader)
    @new_function ||= create_new_function(loader)
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
    reader.read(implementation_class, value_count, deserializer)
  end

  # Write an instance of this type using a serializer
  # @param [Object] value the instance to write
  # @param [Serialization::Serializer] the serializer to write to
  # @api private
  def write(value, serializer)
    writer.write(self, value, serializer)
  end

    # @api private
  def create_new_function(loader)
    impl_class = implementation_class
    class_name = impl_class.name || "Anonymous Ruby class for #{name}"

    (param_names, param_types, required_param_count) = parameter_info

    # Create the callable with a size that reflects the required and optional parameters
    param_types << required_param_count
    param_types << param_names.size

    create_type = TypeFactory.callable(*param_types)
    from_hash_type = TypeFactory.callable(i12n_type, 1, 1)

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
        dispatcher.add_dispatch(from_hash_type, :from_hash, ['hash'], nil, EMPTY_ARRAY, EMPTY_ARRAY, false)
        def from_hash(hash)
          self.class.impl_class.from_asserted_hash(hash)
        end
      end

      # Add the dispatch that uses the standard #new method on the class. It's assumed that the #new
      # method performs no assertions.
      dispatcher.add_dispatch(create_type, :create, param_names, nil, EMPTY_ARRAY, EMPTY_ARRAY, false)
      def create(*args)
        self.class.impl_class.new(*args)
      end
    end
  end

  # @api private
  def implementation_class
    if @implementation_class.nil?
      impl_name = Loaders.implementation_registry.module_name_for_type(self)
      if impl_name.nil?
        # Use generator to create a default implementation
        @implementation_class = RubyGenerator.new.create_class(self)
      else
        # Can the mapping be loaded?
        class_name = impl_name[0]
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
  # @return [(Array<String>, Array<PAnyType>, Integer)] array of parameter names, array of parameter types, and a count reflecting the required number of parameters
  def parameter_info(attr_readers = false)
    # Create a types and a names array where optional entries ends up last
    opt_types = []
    opt_names = []
    non_opt_types = []
    non_opt_names = []
    i12n_type.elements.each do |se|
      if se.key_type.is_a?(POptionalType)
        opt_names << (attr_readers ? attr_reader_name(se) : se.name)
        opt_types << se.value_type
      else
        non_opt_names << (attr_readers ? attr_reader_name(se) : se.name)
        non_opt_types << se.value_type
      end
    end
    param_names = non_opt_names + opt_names
    param_types = non_opt_types + opt_types

    [param_names, param_types, non_opt_types.size]
  end

  # @api private
  def attr_reader_name(se)
    if se.value_type.is_a?(PBooleanType) || se.value_type.is_a?(POptionalType) && se.value_type.type.is_a?(PBooleanType)
      "#{se.name}?"
    else
      se.name
    end
  end

  # @api private
  def include_class_in_equality?
    @equality_include_type && !(@parent.is_a?(PObjectType) && parent.include_class_in_equality?)
  end

  # @api private
  def initialize_from_hash(i12n_hash)
    TypeAsserter.assert_instance_of('object initializer', TYPE_OBJECT_I12N, i12n_hash)

    # Name given to the loader have higher precedence than a name declared in the type
    @name ||= i12n_hash[KEY_NAME]
    @name.freeze unless @name.nil?

    @parent = i12n_hash[KEY_PARENT]

    parent_members = EMPTY_HASH
    parent_object_type = nil
    unless @parent.nil?
      check_self_recursion(self)
      rp = resolved_parent
      if rp.is_a?(PObjectType)
        parent_object_type = rp
        parent_members = rp.members(true)
      end
    end

    attr_specs = i12n_hash[KEY_ATTRIBUTES]
    unless attr_specs.nil? || attr_specs.empty?
      @attributes = Hash[attr_specs.map do |key, attr_spec|
        attr_spec = { KEY_TYPE => TypeAsserter.assert_instance_of(nil, PType::DEFAULT, attr_spec) { "attribute #{label}[#{key}]" } } unless attr_spec.is_a?(Hash)
        attr = PAttribute.new(key, self, attr_spec)
        [attr.name, attr.assert_override(parent_members)]
      end].freeze
    end

    func_specs = i12n_hash[KEY_FUNCTIONS]
    unless func_specs.nil? || func_specs.empty?
      @functions = Hash[func_specs.map do |key, func_spec|
        func_spec = { KEY_TYPE => TypeAsserter.assert_instance_of(nil, TYPE_FUNCTION_TYPE, func_spec) { "function #{label}[#{key}]" } } unless func_spec.is_a?(Hash)
        func = PFunction.new(key, self, func_spec)
        name = func.name
        raise Puppet::ParseError, "#{func.label} conflicts with attribute with the same name" if @attributes.include?(name)
        [name, func.assert_override(parent_members)]
      end].freeze
    end

    @equality_include_type = i12n_hash[KEY_EQUALITY_INCLUDE_TYPE]
    @equality_include_type = true if @equality_include_type.nil?

    equality = i12n_hash[KEY_EQUALITY]
    equality = [equality] if equality.is_a?(String)
    if equality.is_a?(Array)
      unless equality.empty?
        raise Puppet::ParseError, 'equality_include_type = false cannot be combined with non empty equality specification' unless @equality_include_type
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
              raise Puppet::ParseError, "#{label} equality is referencing #{attr.label} which is included in equality of #{including_parent.label}"
            end
          end

          unless attr.is_a?(PAttribute)
            raise Puppet::ParseError, "#{label} equality is referencing non existent attribute '#{attr_name}'" if attr.nil?
            raise Puppet::ParseError, "#{label} equality is referencing #{attr.label}. Only attribute references are allowed"
          end
          if attr.kind == ATTRIBUTE_KIND_CONSTANT
            raise Puppet::ParseError, "#{label} equality is referencing constant #{attr.label}. Reference to constant is not allowed in equality"
          end
        end
      end
      equality.freeze
    end
    @equality = equality

    @checks = i12n_hash[KEY_CHECKS]
    init_annotatable(i12n_hash)
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
  def i12n_type
    @i12n_type ||= create_i12n_type
  end

  # Creates the type that a initialization hash used for creating instances of this type must conform to.
  #
  # @return [PStructType] the initialization hash type
  # @api private
  def create_i12n_type
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

  # The i12n_hash is primarily intended for serialization and string representation purposes. It creates a hash
  # suitable for passing to {PObjectType#new(i12n_hash)}
  #
  # @return [Hash{String=>Object}] the features hash
  # @api public
  def i12n_hash(include_name = true)
    result = super()
    result[KEY_NAME] = @name if include_name && !@name.nil?
    result[KEY_PARENT] = @parent unless @parent.nil?
    result[KEY_ATTRIBUTES] = compressed_members_hash(@attributes) unless @attributes.empty?
    result[KEY_FUNCTIONS] = compressed_members_hash(@functions) unless @functions.empty?
    result[KEY_EQUALITY] = @equality unless @equality.nil?
    result[KEY_CHECKS] = @checks unless @checks.nil?
    result
  end

  def eql?(o)
    self.class == o.class &&
      @name == o.name &&
      @parent == o.parent &&
      @attributes == o.attributes &&
      @functions == o.functions &&
      @equality == o.equality &&
      @checks == o.checks
  end

  def hash
    @name.nil? ? [@parent, @attributes, @functions].hash : @name.hash
  end

  def kind_of_callable?(optional=true, guard = nil)
    @parent.nil? ? false : @parent.kind_of_callable?(optional, guard)
  end

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
  end

  def iterable?(guard = nil)
    @parent.nil? ? false : @parent.iterable?(guard)
  end

  def iterable_type(guard = nil)
    @parent.nil? ? false : @parent.iterable_type(guard)
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
    @name || '<anonymous object type>'
  end

  # @api private
  def resolved_parent
    parent = @parent
    while parent.is_a?(PTypeAliasType)
      parent = parent.resolved_type
    end
    parent
  end

  protected

  # An Object type is only assignable from another Object type. The other type
  # or one of its parents must be equal to this type.
  def _assignable?(o, guard)
    if self == o
      true
    else
      if o.is_a?(PObjectType)
        op = o.parent
        op.nil? ? false : assignable?(op, guard)
      else
        false
      end
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

  private

  def compressed_members_hash(features)
    Hash[features.values.map do |feature|
      fh = feature.i12n_hash
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
      p = type.parent
      return type if p.nil?
      return type unless p.equality_attributes.include?(attr.name)
      type = p
    end
    nil
  end

  def guarded_recursion(guard, dflt)
    if @self_recursion
      guard ||= RecursionGuard.new
      (guard.add_this(self) & RecursionGuard::SELF_RECURSION_IN_THIS) == 0 ? yield(guard) : dflt
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
