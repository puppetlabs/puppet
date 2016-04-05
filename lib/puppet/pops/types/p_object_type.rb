module Puppet::Pops
module Types

# @api public
class PObjectType < PAnyType
  KEY_ANNOTATIONS = 'annotations'.freeze
  KEY_ATTRIBUTES = 'attributes'.freeze
  KEY_CHECKS = 'checks'.freeze
  KEY_EQUALITY = 'equality'.freeze
  KEY_EQUALITY_INCLUDE_TYPE = 'equality_include_type'.freeze
  KEY_FINAL = 'final'.freeze
  KEY_FUNCTIONS = 'functions'.freeze
  KEY_KIND = 'kind'.freeze
  KEY_OVERRIDE = 'override'.freeze
  KEY_PARENT = 'parent'.freeze
  KEY_TYPE = 'type'.freeze
  KEY_VALUE = 'value'.freeze

  ATTRIBUTE_KIND_CONSTANT = 'constant'.freeze
  ATTRIBUTE_KIND_DERIVED = 'derived'.freeze
  ATTRIBUTE_KIND_GIVEN_OR_DERIVED = 'given_or_derived'.freeze
  TYPE_ATTRIBUTE_KIND = TypeFactory.enum(ATTRIBUTE_KIND_CONSTANT, ATTRIBUTE_KIND_DERIVED, ATTRIBUTE_KIND_GIVEN_OR_DERIVED)

  TYPE_ANNOTATION_KEY_TYPE = PType::DEFAULT # TBD
  TYPE_ANNOTATION_VALUE_TYPE = PStructType::DEFAULT #TBD
  TYPE_ANNOTATIONS = PHashType.new(TYPE_ANNOTATION_KEY_TYPE, TYPE_ANNOTATION_VALUE_TYPE)

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
    KEY_PARENT => TypeFactory.optional(PType::DEFAULT),
    KEY_ATTRIBUTES => TypeFactory.optional(TYPE_ATTRIBUTES),
    KEY_FUNCTIONS => TypeFactory.optional(TYPE_FUNCTIONS),
    KEY_EQUALITY => TypeFactory.optional(TYPE_EQUALITY),
    KEY_EQUALITY_INCLUDE_TYPE => TypeFactory.optional(PBooleanType::DEFAULT),
    KEY_CHECKS =>  TypeFactory.optional(TYPE_CHECKS),
    KEY_ANNOTATIONS =>  TypeFactory.optional(TYPE_ANNOTATIONS)
  })

  # @abstract Encapsulates behavior common to {PAttribute} and {PFunction}
  # @api public
  class PAnnotatedMember

    # @return [String] the name of this member
    # @api public
    attr_reader :name

    # @return [PAnyType] the type of this member
    # @api public
    attr_reader :type

    # @return [Hash{PType => Hash}] the annotations or `nil`
    # @api public
    attr_reader :annotations

    # @param name [String] The name of the member
    # @param [Hash{String=>Object}] i12n_hash
    # @option i12n_hash [PAnyType] 'type' The member type (required)
    # @option i12n_hash [Boolean] 'override' `true` if this feature must override an inherited feature. Default is `false`.
    # @option i12n_hash [Boolean] 'final' `true` if this feature cannot be overridden. Default is `false`.
    # @option i12n_hash [Hash{PType => Hash}] 'annotations' Annotations hash. Default is `nil`.
    # @api public
    def initialize(name, i12n_hash)
      @name = name
      @type = i12n_hash[KEY_TYPE]
      @override = i12n_hash[KEY_OVERRIDE]
      @override = false if @override.nil?
      @final = i12n_hash[KEY_FINAL]
      @final = false if @final.nil?
      @annotations = i12n_hash[KEY_ANNOTATIONS]
      @annotations.freeze unless @annotations.nil?
    end

    # Delegates to the contained type
    # @param visitor [TypeAcceptor] the visitor
    # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
    # @api public
    def accept(visitor, guard)
      @type.accept(visitor, guard)
      @annotations.each_key { |key| key.accept(visitor, guard) } unless @annotations.nil?
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
        raise Puppet::ParseError, "expected #{label} to override an inherited #{feature_type}" if @override
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
      raise Puppet::ParseError, "#{member.label} overrides inherited #{feature_type}" unless self.class == member.class
      raise Puppet::ParseError, "attempt to override final #{label}" if @final
      raise Puppet::ParseError, "#{label} attempts to override without having override defined" unless member.override?
      raise Puppet::ParseError, "attempt to override #{label} with a type that does not match" unless @type.assignable?(member.type)
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
      self.class == o.class && @name == o.name && @type == o.type && @override == o.override? && @final == o.final? && @annotations == o.annotations
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
      raise NotImplementedError, "'#{self.class.name}' should implement #feature_type"
    end

    # @api private
    def label
      "#{feature_type} '#{name}'"
    end
  end

  # Describes a named Attribute in an Object type
  # @api public
  class PAttribute < PAnnotatedMember

    # @return [String,nil] The attribute kind as defined by #TYPE_ATTRIBUTE_KIND, or `nil` to
    #   indicate that
    attr_reader :kind

    # @return [Object] the default value or the symbol :default to denote that there is no default value
    # @api public
    attr_reader :value

    # @param name [String] The name of the attribute
    # @param [Hash{String=>Object}] i12n_hash
    # @option i12n_hash [PAnyType] 'type' The attribute type (required)
    # @option i12n_hash [Object] 'value' The default value, must be an instanceof the given `type` (optional)
    # @option i12n_hash [String] 'kind' The attribute kind, matching #TYPE_ATTRIBUTE_KIND
    # @api public
    def initialize(name, i12n_hash)
      super(name, TypeAsserter.assert_instance_of(["initializer for attribute '%s'", name], TYPE_ATTRIBUTE, i12n_hash))
      @kind = i12n_hash[KEY_KIND]
      @final = true if @kind == ATTRIBUTE_KIND_CONSTANT # final is implied

      if i12n_hash.include?(KEY_VALUE)
        if @kind == ATTRIBUTE_KIND_DERIVED || @kind == ATTRIBUTE_KIND_GIVEN_OR_DERIVED
          raise Puppet::ParseError, "#{label} of kind '#{@kind}' cannot be combined with an attribute value"
        end
        @value = TypeAsserter.assert_instance_of(nil, type, i12n_hash[KEY_VALUE]) {"#{label} #{KEY_VALUE}" }
      else
        raise Puppet::ParseError, "#{label} of kind 'constant' requires a value" if @kind == ATTRIBUTE_KIND_CONSTANT
        @value = :default
      end
    end

    # @api public
    def eql?(o)
      super && @kind == o.kind && @value == o.value
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
      hash[KEY_VALUE] = @value unless @value == :default
      hash
    end

    # @return [Boolean] `true` if a value has been defined for this attribute. The value may be `nil`
    def value?
      value != :default
    end

    # @api private
    def feature_type
      'attribute'
    end
  end

  # Describes a named Function in an Object type
  # @api public
  class PFunction < PAnnotatedMember
    def initialize(name, i12n_hash)
      super(name, TypeAsserter.assert_instance_of(["initializer for function '%s'", name], TYPE_FUNCTION, i12n_hash))
    end

    # @api private
    def feature_type
      'function'
    end
  end

  attr_reader :parent
  attr_reader :attributes
  attr_reader :functions
  attr_reader :equality
  attr_reader :checks
  attr_reader :annotations

  # @param i12n_hash [Hash{String=>Object}] The hash describing the Object features
  #
  # @api public
  def initialize(i12n_hash)
    TypeAsserter.assert_instance_of('object initializer', TYPE_OBJECT_I12N, i12n_hash)

    @attributes = EMPTY_HASH
    @functions = EMPTY_HASH
    @parent = i12n_hash[KEY_PARENT]

    parent_members = EMPTY_HASH
    parent_object_type = nil
    unless @parent.nil?
      rp = resolved_parent
      if rp.is_a?(PObjectType)
        parent_object_type = rp
        parent_members = rp.members(true)
      end
    end

    attr_specs = i12n_hash[KEY_ATTRIBUTES]
    unless attr_specs.nil? || attr_specs.empty?
      @attributes = Hash[attr_specs.map do |key, attr_spec|
        attr_spec = { KEY_TYPE => TypeAsserter.assert_instance_of(["attribute '%s'", key], PType::DEFAULT, attr_spec) } unless attr_spec.is_a?(Hash)
        attr = PAttribute.new(key, attr_spec)
        [attr.name, attr.assert_override(parent_members)]
      end].freeze
    end

    func_specs = i12n_hash[KEY_FUNCTIONS]
    unless func_specs.nil? || func_specs.empty?
      @functions = Hash[func_specs.map do |key, func_spec|
        func_spec = { KEY_TYPE => TypeAsserter.assert_instance_of(["function '%s'", key], TYPE_FUNCTION_TYPE, func_spec) } unless func_spec.is_a?(Hash)
        func = PFunction.new(key, func_spec)
        name = func.name
        raise Puppet::ParseError, "function '#{key}' conflicts with attribute with the same name" if @attributes.include?(name)
        [name, func.assert_override(parent_members)]
      end].freeze
    end

    @equality_include_type = i12n_hash[KEY_EQUALITY_INCLUDE_TYPE]
    @equality_include_type = true if @equality_include_type.nil?

    equality = i12n_hash[KEY_EQUALITY]
    equality = [equality] if equality.is_a?(String)
    if equality.is_a?(Array)
      unless equality.empty?
        raise Puppet::ParseError, 'equality_include_type = false cannot be combined with attributes' unless @equality_include_type
        parent_eq_attrs = nil
        equality.each do |attr_name|

          attr = parent_members[attr_name]
          if attr.nil?
            attr = @attributes[attr_name] || @functions[attr_name]
          elsif attr.is_a?(PAttribute)
            # Assert that attribute is not already include by parent equality
            parent_eq_attrs ||= parent_object_type.equality_attributes
            if parent_eq_attrs.include?(attr_name)
              raise Puppet::ParseError, "equality is referencing attribute '#{attr_name}' which is already included by parent equality"
            end
          end

          raise Puppet::ParseError, "equality is referencing non existent attribute '#{attr_name}'" if attr.nil?
          raise Puppet::ParseError, "equality is referencing function '#{attr_name}'" unless attr.is_a?(PAttribute)
          raise Puppet::ParseError, "equality is referencing constant attribute '#{attr_name}'" if attr.kind == ATTRIBUTE_KIND_CONSTANT
        end
      end
      equality.freeze
    end
    @equality = equality

    @checks = i12n_hash[KEY_CHECKS]

    @annotations = i12n_hash[KEY_ANNOTATIONS]
    @annotations.freeze unless @annotations.nil?

    @hash = [parent, @attributes, @functions, @equality, @checks, @annotations].hash
  end

  def [](name)
    @attributes[name] || @functions[name] || super
  end

  def accept(visitor, guard)
    super
    @parent.accept(visitor, guard) unless parent.nil?
    @attributes.values.each { |a| a.accept(visitor, guard) }
    @functions.values.each { |f| f.accept(visitor, guard) }
    @annotations.each_key { |key| key.accept(visitor, guard) } unless @annotations.nil?
  end

  def callable_args?(callable, guard)
    @parent.nil? ? false : @parent.callable_args?(callable, guard)
  end

  # The i12n_hash is primarily intended for serialization and string representation purposes. It creates a hash
  # suitable for passing to {PObjectType#new(i12n_hash)}
  #
  # @return [Hash{String=>Object}] the features hash
  # @api public
  def i12n_hash
    result = {}
    result[KEY_PARENT] = @parent unless @parent.nil?
    result[KEY_ATTRIBUTES] = compressed_members_hash(@attributes) unless @attributes.empty?
    result[KEY_FUNCTIONS] = compressed_members_hash(@functions) unless @functions.empty?
    result[KEY_EQUALITY] = @equality unless @equality.nil?
    result[KEY_CHECKS] = @checks unless @checks.nil?
    result[KEY_ANNOTATIONS] = @annotations unless @annotations.nil?
    result
  end

  def eql?(o)
    self.class == o.class &&
      @parent == o.parent &&
      @attributes == o.attributes &&
      @functions == o.functions &&
      @equality == o.equality &&
      @checks == o.checks &&
      @annotations == o.annotations
  end

  def hash
    @hash
  end

  def kind_of_callable?(optional=true, guard = nil)
    @parent.nil? ? false : @parent.kind_of_callable?(optional, guard)
  end

  def instance?(o, guard = nil)
    assignable(TypeCalculator.infer(o), guard)
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
      raise Puppet::Error, "The Object type aliased by '#{originator}' inherits from itself" if @parent.equal?(originator)
      @parent.check_self_recursion(originator)
    end
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

  # @api private
  def label
    'object'
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

  def resolved_parent
    parent = @parent
    while parent.is_a?(PTypeAliasType)
      parent = parent.resolved_type
    end
    parent
  end
end
end
end
