require_relative 'iterable'
require_relative 'enumeration'
require_relative 'recursion_guard'
require_relative 'type_acceptor'
require_relative 'type_asserter'
require_relative 'type_assertion_error'
require_relative 'type_conversion_error'
require_relative 'type_formatter'
require_relative 'type_calculator'
require_relative 'type_factory'
require_relative 'type_parser'
require_relative 'class_loader'
require_relative 'type_mismatch_describer'
require_relative 'puppet_object'

module Puppet::Pops
module Types

# The EMPTY_xxx declarations is for backward compatibility. They should not be explicitly referenced

# @api private
# @deprecated
EMPTY_HASH = Puppet::Pops::EMPTY_HASH

# @api private
# @deprecated
EMPTY_ARRAY = Puppet::Pops::EMPTY_ARRAY

# @api private
# @deprecated
EMPTY_STRING = Puppet::Pops::EMPTY_STRING

# The Types model is a model of Puppet Language types.
#
# The {TypeCalculator} should be used to answer questions about types. The {TypeFactory} or {TypeParser} should be used
# to create an instance of a type whenever one is needed.
#
# The implementation of the Types model contains methods that are required for the type objects to behave as
# expected when comparing them and using them as keys in hashes. (No other logic is, or should be included directly in
# the model's classes).
#
# @api public
#
class TypedModelObject < Object
  include PuppetObject
  include Visitable
  include Adaptable

  def self._pcore_type
    @type
  end

  def self.create_ptype(loader, ir, parent_name, attributes_hash = EMPTY_HASH)
    @type = Pcore::create_object_type(loader, ir, self, "Pcore::#{simple_name}Type", "Pcore::#{parent_name}", attributes_hash)
  end

  def self.register_ptypes(loader, ir)
    types = [
      Annotation.register_ptype(loader, ir),
      RubyMethod.register_ptype(loader, ir),
    ]
    Types.constants.each do |c|
      next if c == :PType || c == :PHostClassType
      cls = Types.const_get(c)
      next unless cls.is_a?(Class) && cls < self
      type = cls.register_ptype(loader, ir)
      types << type unless type.nil?
    end
    types.each { |type| type.resolve(loader) }
  end
end

# Base type for all types
# @api public
#
class PAnyType < TypedModelObject

  def self.register_ptype(loader, ir)
    @type = Pcore::create_object_type(loader, ir, self, 'Pcore::AnyType', 'Any', EMPTY_HASH)
  end

  def self.create(*args)
    # NOTE! Important to use self::DEFAULT and not just DEFAULT since the latter yields PAnyType::DEFAULT
    args.empty? ? self::DEFAULT : new(*args)
  end

  # Accept a visitor that will be sent the message `visit`, once with `self` as the
  # argument. The visitor will then visit all types that this type contains.
  #
  def accept(visitor, guard)
    visitor.visit(self, guard)
  end

  # Checks if _o_ is a type that is assignable to this type.
  # If _o_ is a `Class` then it is first converted to a type.
  # If _o_ is a Variant, then it is considered assignable when all its types are assignable
  #
  # The check for assignable must be guarded against self recursion since `self`, the given type _o_,
  # or both, might be a `TypeAlias`. The initial caller of this method will typically never care
  # about this and hence pass only the first argument, but as soon as a check of a contained type
  # encounters a `TypeAlias`, then a `RecursionGuard` instance is created and passed on in all
  # subsequent calls. The recursion is allowed to continue until self recursion has been detected in
  # both `self` and in the given type. At that point the given type is considered to be assignable
  # to `self` since all checks up to that point were positive.
  #
  # @param o [Class,PAnyType] the class or type to test
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean] `true` when _o_ is assignable to this type
  # @api public
  def assignable?(o, guard = nil)
    case o
    when Class
      # Safe to call _assignable directly since a Class never is a Unit or Variant
      _assignable?(TypeCalculator.singleton.type(o), guard)
    when PUnitType
      true
    when PTypeAliasType
      # An alias may contain self recursive constructs.
      if o.self_recursion?
        guard ||= RecursionGuard.new
        if guard.add_that(o) == RecursionGuard::SELF_RECURSION_IN_BOTH
          # Recursion detected both in self and other. This means that other is assignable
          # to self. This point would not have been reached otherwise
          true
        else
          assignable?(o.resolved_type, guard)
        end
      else
        assignable?(o.resolved_type, guard)
      end
    when PVariantType
      # Assignable if all contained types are assignable, or if this is exactly Any
      return true if self.class == PAnyType
      # An empty variant may be assignable to NotUndef[T] if T is assignable to empty variant
      return _assignable?(o, guard) if is_a?(PNotUndefType) && o.types.empty?
      !o.types.empty? && o.types.all? { |vt| assignable?(vt, guard) }
    when POptionalType
      # Assignable if undef and contained type is assignable
      assignable?(PUndefType::DEFAULT) && (o.type.nil? || assignable?(o.type))
    when PNotUndefType
      if !(o.type.nil? || o.type.assignable?(PUndefType::DEFAULT))
        assignable?(o.type, guard)
      else
        _assignable?(o, guard)
      end
    else
      _assignable?(o, guard)
    end
  end

  # Returns `true` if this instance is a callable that accepts the given _args_type_ type
  #
  # @param args_type [PAnyType] the arguments to test
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean] `true` if this instance is a callable that accepts the given _args_
  def callable?(args_type, guard = nil)
    args_type.is_a?(PAnyType) && kind_of_callable? && args_type.callable_args?(self, guard)
  end

  # Returns `true` if this instance is a callable that accepts the given _args_
  #
  # @param args [Array] the arguments to test
  # @param block [Proc] block, or nil if not called with a block
  # @return [Boolean] `true` if this instance is a callable that accepts the given _args_
  def callable_with?(args,  block = nil)
    false
  end

  # Returns `true` if this instance is considered valid as arguments to the given `callable`
  # @param callable [PAnyType] the callable
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean] `true` if this instance is considered valid as arguments to the given `callable`
  # @api private
  def callable_args?(callable, guard)
    false
  end

  # Called from the `PTypeAliasType` when it detects self recursion. The default is to do nothing
  # but some self recursive constructs are illegal such as when a `PObjectType` somehow inherits itself
  # @param originator [PTypeAliasType] the starting point for the check
  # @raise Puppet::Error if an illegal self recursion is detected
  # @api private
  def check_self_recursion(originator)
  end

  # Generalizes value specific types. Types that are not value specific will return `self` otherwise
  # the generalized type is returned.
  #
  # @return [PAnyType] The generalized type
  # @api public
  def generalize
    # Applicable to all types that have no variables
    self
  end

  # Returns the loader that loaded this type.
  # @return [Loaders::Loader] the loader
  def loader
    Loaders.static_loader
  end

  # Normalizes the type. This does not change the characteristics of the type but it will remove duplicates
  # and constructs like NotUndef[T] where T is not assignable from Undef and change Variant[*T] where all
  # T are enums into an Enum.
  #
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [PAnyType] The iterable type that this type is assignable to or `nil`
  # @api public
  def normalize(guard = nil)
    self
  end

  # Called from the TypeParser once it has found a type using the Loader to enable that this type can
  # resolve internal type expressions using a loader. Presently, this method is a no-op for all types
  # except the {{PTypeAliasType}}.
  #
  # @param loader [Loader::Loader] loader to use
  # @return [PTypeAliasType] the receiver of the call, i.e. `self`
  # @api private
  def resolve(loader)
    self
  end

  # Responds `true` for all callables, variants of callables and unless _optional_ is
  # false, all optional callables.
  # @param optional [Boolean]
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean] `true`if this type is considered callable
  # @api private
  def kind_of_callable?(optional = true, guard = nil)
    false
  end

  # Returns `true` if an instance of this type is iterable, `false` otherwise
  # The method #iterable_type must produce a `PIterableType` instance when this
  # method returns `true`
  #
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean] flag to indicate if instances of  this type is iterable.
  def iterable?(guard = nil)
    false
  end

  # Returns the `PIterableType` that this type should be assignable to, or `nil` if no such type exists.
  # A type that returns a `PIterableType` must respond `true` to `#iterable?`.
  #
  # @example
  #     Any Collection[T] is assignable to an Iterable[T]
  #     A String is assignable to an Iterable[String] iterating over the strings characters
  #     An Integer is assignable to an Iterable[Integer] iterating over the 'times' enumerator
  #     A Type[T] is assignable to an Iterable[Type[T]] if T is an Integer or Enum
  #
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [PIterableType,nil] The iterable type that this type is assignable to or `nil`
  # @api private
  def iterable_type(guard = nil)
    nil
  end

  def hash
    self.class.hash
  end

  # Returns true if the given argument _o_ is an instance of this type
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean]
  # @api public
  def instance?(o, guard = nil)
    true
  end

  # An object is considered to really be an instance of a type when something other than a
  # TypeAlias or a Variant responds true to a call to {#instance?}.
  #
  # @return [Integer] -1 = is not instance, 0 = recursion detected, 1 = is instance
  # @api private
  def really_instance?(o, guard = nil)
    instance?(o, guard) ? 1 : -1
  end

  def eql?(o)
    self.class == o.class
  end

  def ==(o)
    eql?(o)
  end

  def simple_name
    self.class.simple_name
  end

  # Strips the class name from all module prefixes, the leading 'P' and the ending 'Type'. I.e.
  # an instance of PVariantType will return 'Variant'
  # @return [String] the simple name of this type
  def self.simple_name
    @simple_name ||= (
      n = name
      n[n.rindex(DOUBLE_COLON)+3..n.size-5].freeze
    )
  end

  def to_alias_expanded_s
    TypeFormatter.new.alias_expanded_string(self)
  end

  def to_s
    TypeFormatter.string(self)
  end

  # Returns the name of the type, without parameters
  # @return [String] the name of the type
  # @api public
  def name
    simple_name
  end

  def create(*args)
    Loaders.find_loader(nil).load(:function, 'new').call({}, self, *args)
  end

  # Create an instance of this type.
  # The default implementation will just dispatch the call to the class method with the
  # same name and pass `self` as the first argument.
  #
  # @return [Function] the created function
  # @raises ArgumentError
  #
  def new_function
    self.class.new_function(self)
  end

  # This default implementation of of a new_function raises an Argument Error.
  # Types for which creating a new instance is supported, should create and return
  # a Puppet Function class by using Puppet:Loaders.create_loaded_function(:new, loader)
  # and return that result.
  #
  # @param type [PAnyType] the type to create a new function for
  # @return [Function] the created function
  # @raises ArgumentError
  #
  def self.new_function(type)
    raise ArgumentError.new("Creation of new instance of type '#{type.to_s}' is not supported")
  end

  # Answers the question if instances of this type can represent themselves as a string that
  # can then be passed to the create method
  #
  # @return [Boolean] whether or not the instance has a canonical string representation
  def roundtrip_with_string?
    false
  end

  # The default instance of this type. Each type in the type system has this constant
  # declared.
  #
  DEFAULT = PAnyType.new

  protected

  # @api private
  def _assignable?(o, guard)
    o.is_a?(PAnyType)
  end

  # Produces the tuple entry at the given index given a tuple type, its from/to constraints on the last
  # type, and an index.
  # Produces nil if the index is out of bounds
  # from must be less than to, and from may not be less than 0
  #
  # @api private
  #
  def tuple_entry_at(tuple_t, to, index)
    regular = (tuple_t.types.size - 1)
    if index < regular
      tuple_t.types[index]
    elsif index < regular + to
      # in the varargs part
      tuple_t.types[-1]
    else
      nil
    end
  end

  # Applies a transformation by sending the given _method_ and _method_args_ to each of the types of the given array
  # and collecting the results in a new array. If all transformation calls returned the type instance itself (i.e. no
  # transformation took place), then this method will return `self`. If a transformation did occur, then this method
  # will either return the transformed array or in case a block was given, the result of calling a given block with
  # the transformed array.
  #
  # @param types [Array<PAnyType>] the array of types to transform
  # @param method [Symbol] The method to call on each type
  # @param method_args [Object] The arguments to pass to the method, if any
  # @return [Object] self, the transformed array, or the result of calling a given block with the transformed array
  # @yieldparam altered_types [Array<PAnyType>] the altered type array
  # @api private
  def alter_type_array(types, method, *method_args)
    modified = false
    modified_types = types.map do |t|
      t_mod = t.send(method, *method_args)
      modified = !t.equal?(t_mod) unless modified
      t_mod
    end
    if modified
      block_given? ? yield(modified_types) : modified_types
    else
      self
    end
  end
end

# @abstract Encapsulates common behavior for a type that contains one type
# @api public
class PTypeWithContainedType < PAnyType
  def self.register_ptype(loader, ir)
    # Abstract type. It doesn't register anything
  end

  attr_reader :type

  def initialize(type)
    @type = type
  end

  def accept(visitor, guard)
    super
    @type.accept(visitor, guard) unless @type.nil?
  end

  def generalize
    if @type.nil?
      self.class::DEFAULT
    else
      ge_type = @type.generalize
      @type.equal?(ge_type) ? self : self.class.new(ge_type)
    end
  end

  def normalize(guard = nil)
    if @type.nil?
      self.class::DEFAULT
    else
      ne_type = @type.normalize(guard)
      @type.equal?(ne_type) ? self : self.class.new(ne_type)
    end
  end

  def hash
    self.class.hash ^ @type.hash
  end

  def eql?(o)
    self.class == o.class && @type == o.type
  end

  def resolve(loader)
    rtype = @type
    rtype = rtype.resolve(loader) unless rtype.nil?
    rtype.equal?(@type) ? self : self.class.new(rtype)
  end
end

# The type of types.
# @api public
#
class PTypeType < PTypeWithContainedType

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
       'type' => {
         KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
         KEY_VALUE => nil
       }
    )
  end

  # Returns a new function that produces a Type instance
  #
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_type, type.loader) do
      dispatch :from_string do
        param 'String[1]', :type_string
      end

      def from_string(type_string)
        TypeParser.singleton.parse(type_string, loader)
      end
    end
  end

  def instance?(o, guard = nil)
    if o.is_a?(PAnyType)
      type.nil? || type.assignable?(o, guard)
    elsif o.is_a?(Module) || o.is_a?(Puppet::Resource) || o.is_a?(Puppet::Parser::Resource)
      @type.nil? ? true : assignable?(TypeCalculator.infer(o))
    else
      false
    end
  end

  def iterable?(guard = nil)
    case @type
    when PEnumType
      true
    when PIntegerType
      @type.finite_range?
    else
      false
    end
  end

  def iterable_type(guard = nil)
    # The types PIntegerType and PEnumType are Iterable
    case @type
    when PEnumType
      # @type describes the element type perfectly since the iteration is made over the
      # contained choices.
      PIterableType.new(@type)
    when PIntegerType
      # @type describes the element type perfectly since the iteration is made over the
      # specified range.
      @type.finite_range? ? PIterableType.new(@type) : nil
    else
      nil
    end
  end

  def eql?(o)
    self.class == o.class && @type == o.type
  end

  DEFAULT = PTypeType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PTypeType)
    return true if @type.nil? # wide enough to handle all types
    return false if o.type.nil? # wider than t
    @type.assignable?(o.type, guard)
  end
end

# For backward compatibility
PType = PTypeType

class PNotUndefType < PTypeWithContainedType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
       'type' => {
         KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
         KEY_VALUE => nil
       }
    )
  end

  def initialize(type = nil)
    super(type.class == PAnyType ? nil : type)
  end

  def instance?(o, guard = nil)
    !(o.nil? || o == :undef) && (@type.nil? || @type.instance?(o, guard))
  end

  def normalize(guard = nil)
    n = super
    if n.type.nil?
      n
    else
      if n.type.is_a?(POptionalType)
        # No point in having an optional in a NotUndef
        PNotUndefType.new(n.type.type).normalize
      elsif !n.type.assignable?(PUndefType::DEFAULT)
        # THe type is NotUndef anyway, so it can be stripped of
        n.type
      else
        n
      end
    end
  end

  def new_function
    # If only NotUndef, then use Unit's null converter
    if type.nil?
      PUnitType.new_function(self)
    else
      type.new_function
    end
  end

  DEFAULT = PNotUndefType.new

  protected

  # @api private
  def _assignable?(o, guard)
    o.is_a?(PAnyType) && !o.assignable?(PUndefType::DEFAULT, guard) && (@type.nil? || @type.assignable?(o, guard))
  end
end

# @api public
#
class PUndefType < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  def instance?(o, guard = nil)
    o.nil? || :undef == o
  end

  # @api private
  def callable_args?(callable_t, guard)
    # if callable_t is Optional (or indeed PUndefType), this means that 'missing callable' is accepted
    callable_t.assignable?(DEFAULT, guard)
  end

  DEFAULT = PUndefType.new

  protected
  # @api private
  def _assignable?(o, guard)
    o.is_a?(PUndefType)
  end
end

# A type private to the type system that describes "ignored type" - i.e. "I am what you are"
# @api private
#
class PUnitType < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  def instance?(o, guard = nil)
    true
  end

  # A "null" implementation - that simply returns the given argument
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_unit, type.loader) do
      dispatch :from_args do
        param          'Any',  :from
      end

      def from_args(from)
        from
      end
    end
  end

  DEFAULT = PUnitType.new

  def assignable?(o, guard=nil)
    true
  end

  protected

  # @api private
  def _assignable?(o, guard)
    true
  end
end

# @api public
#
class PDefaultType < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  def instance?(o, guard = nil)
    # Ensure that Symbol.== is called here instead of something unknown
    # that is implemented on o
    :default == o
  end

  DEFAULT = PDefaultType.new

  protected
  # @api private
  def _assignable?(o, guard)
    o.is_a?(PDefaultType)
  end
end

# Type that is a Scalar
# @api public
#
class PScalarType < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  def instance?(o, guard = nil)
    if o.is_a?(String) || o.is_a?(Numeric) || o.is_a?(TrueClass) || o.is_a?(FalseClass) || o.is_a?(Regexp)
      true
    elsif o.instance_of?(Array) || o.instance_of?(Hash) || o.is_a?(PAnyType) || o.is_a?(NilClass)
      false
    else
      assignable?(TypeCalculator.infer(o))
    end
  end

  def roundtrip_with_string?
    true
  end

  DEFAULT = PScalarType.new

  protected

  # @api private
  def _assignable?(o, guard)
    o.is_a?(PScalarType) ||
      PStringType::DEFAULT.assignable?(o, guard) ||
      PIntegerType::DEFAULT.assignable?(o, guard) ||
      PFloatType::DEFAULT.assignable?(o, guard) ||
      PBooleanType::DEFAULT.assignable?(o, guard) ||
      PRegexpType::DEFAULT.assignable?(o, guard) ||
      PSemVerType::DEFAULT.assignable?(o, guard) ||
      PSemVerRangeType::DEFAULT.assignable?(o, guard) ||
      PTimespanType::DEFAULT.assignable?(o, guard) ||
      PTimestampType::DEFAULT.assignable?(o, guard)
  end
end

# Like Scalar but limited to Json Data.
# @api public
#
class PScalarDataType < PScalarType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarType')
  end

  def instance?(o, guard = nil)
    return o.is_a?(String) || o.is_a?(Integer) || o.is_a?(Float) || o.is_a?(TrueClass) || o.is_a?(FalseClass)
  end

  DEFAULT = PScalarDataType.new

  protected

  # @api private
  def _assignable?(o, guard)
    o.is_a?(PScalarDataType) ||
      PStringType::DEFAULT.assignable?(o, guard) ||
      PIntegerType::DEFAULT.assignable?(o, guard) ||
      PFloatType::DEFAULT.assignable?(o, guard) ||
      PBooleanType::DEFAULT.assignable?(o, guard)
  end
end

# A string type describing the set of strings having one of the given values
# @api public
#
class PEnumType < PScalarDataType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarDataType',
      'values' => PArrayType.new(PStringType::NON_EMPTY),
      'case_insensitive' => { 'type' => PBooleanType::DEFAULT, 'value' => false })
  end

  attr_reader :values, :case_insensitive

  def initialize(values, case_insensitive = false)
    @values = values.uniq.sort.freeze
    @case_insensitive = case_insensitive
  end

  def case_insensitive?
    @case_insensitive
  end

  # Returns Enumerator if no block is given, otherwise, calls the given
  # block with each of the strings for this enum
  def each(&block)
    r = Iterable.on(self)
    block_given? ? r.each(&block) : r
  end

  def generalize
    # General form of an Enum is a String
    if @values.empty?
      PStringType::DEFAULT
    else
      range = @values.map(&:size).minmax
      PStringType.new(PIntegerType.new(range.min, range.max))
    end
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    # An instance of an Enum is a String
    PStringType::ITERABLE_TYPE
  end

  def hash
    @values.hash ^ @case_insensitive.hash
  end

  def eql?(o)
    self.class == o.class && @values == o.values && @case_insensitive == o.case_insensitive?
  end

  def instance?(o, guard = nil)
    if o.is_a?(String)
      @case_insensitive ? @values.any? { |p| p.casecmp(o) == 0 } : @values.any? { |p| p == o }
    else
      false
    end
  end

  DEFAULT = PEnumType.new(EMPTY_ARRAY)

  protected

  # @api private
  def _assignable?(o, guard)
    return true if self == o
    svalues = values
    if svalues.empty?
      return true if o.is_a?(PStringType) || o.is_a?(PEnumType) || o.is_a?(PPatternType)
    end
    case o
      when PStringType
        # if the contained string is found in the set of enums
        instance?(o.value, guard)
      when PEnumType
        !o.values.empty? && (case_insensitive? || !o.case_insensitive?) && o.values.all? { |s| instance?(s, guard) }
      else
        false
    end
  end
end

INTEGER_HEX = '(?:0[xX][0-9A-Fa-f]+)'
INTEGER_OCT = '(?:0[0-7]+)'
INTEGER_BIN = '(?:0[bB][01]+)'
INTEGER_DEC = '(?:0|[1-9]\d*)'
SIGN_PREFIX = '[+-]?\s*'

OPTIONAL_FRACTION = '(?:\.\d+)?'
OPTIONAL_EXPONENT = '(?:[eE]-?\d+)?'
FLOAT_DEC = '(?:' + INTEGER_DEC + OPTIONAL_FRACTION + OPTIONAL_EXPONENT + ')'

INTEGER_PATTERN = '\A' + SIGN_PREFIX + '(?:' + INTEGER_DEC + '|' + INTEGER_HEX + '|' + INTEGER_OCT + '|' + INTEGER_BIN + ')\z'
FLOAT_PATTERN = '\A' + SIGN_PREFIX + '(?:' + FLOAT_DEC + '|' + INTEGER_HEX + '|' + INTEGER_OCT + '|' + INTEGER_BIN + ')\z'

# @api public
#
class PNumericType < PScalarDataType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarDataType',
      'from' => { KEY_TYPE => POptionalType.new(PNumericType::DEFAULT), KEY_VALUE => nil },
      'to' => { KEY_TYPE => POptionalType.new(PNumericType::DEFAULT), KEY_VALUE => nil }
    )
  end

  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_numeric, type.loader) do
      local_types do
        type "Convertible = Variant[Integer, Float, Boolean, Pattern[/#{FLOAT_PATTERN}/], Timespan, Timestamp]"
        type 'NamedArgs   = Struct[{from => Convertible, Optional[abs] => Boolean}]'
      end

      dispatch :from_args do
        param          'Convertible',  :from
        optional_param 'Boolean',      :abs
      end

      dispatch :from_hash do
        param          'NamedArgs',  :hash_args
      end

      argument_mismatch :on_error do
        param          'Any',     :from
        optional_param 'Boolean', :abs
      end

      def from_args(from, abs = false)
        result = from_convertible(from)
        abs ? result.abs : result
      end

      def from_hash(args_hash)
        from_args(args_hash['from'], args_hash['abs'] || false)
      end

      def from_convertible(from)
        case from
        when Float
          from
        when Integer
          from
        when Time::TimeData
          from.to_f
        when TrueClass
          1
        when FalseClass
          0
        else
          begin
            if from[0] == '0' && (from[1].downcase == 'b' || from[1].downcase == 'x')
              Integer(from)
            else
              Puppet::Pops::Utils.to_n(from)
            end
          rescue TypeError => e
            raise TypeConversionError.new(e.message)
          rescue ArgumentError => e
            raise TypeConversionError.new(e.message)
          end
        end
      end

      def on_error(from, abs = false)
        if from.is_a?(String)
          _("The string '%{str}' cannot be converted to Numeric") % { str: from }
        else
          t = TypeCalculator.singleton.infer(from).generalize
          _("Value of type %{type} cannot be converted to Numeric") % { type: t }
        end
      end
    end
  end

  def initialize(from, to = Float::INFINITY)
    from = -Float::INFINITY if from.nil? || from == :default
    to = Float::INFINITY if to.nil? || to == :default
    raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{from}, #{to}" if from > to
    @from = from
    @to = to
  end

  # Checks if this numeric range intersects with another
  #
  # @param o [PNumericType] the range to compare with
  # @return [Boolean] `true` if this range intersects with the other range
  # @api public
  def intersect?(o)
    self.class == o.class && !(@to < o.numeric_from || o.numeric_to < @from)
  end

  # Returns the lower bound of the numeric range or `nil` if no lower bound is set.
  # @return [Float,Integer]
  def from
    @from == -Float::INFINITY ? nil : @from
  end

  # Returns the upper bound of the numeric range or `nil` if no upper bound is set.
  # @return [Float,Integer]
  def to
    @to == Float::INFINITY ? nil : @to
  end

  # Same as #from but will return `-Float::Infinity` instead of `nil` if no lower bound is set.
  # @return [Float,Integer]
  def numeric_from
    @from
  end

  # Same as #to but will return `Float::Infinity` instead of `nil` if no lower bound is set.
  # @return [Float,Integer]
  def numeric_to
    @to
  end

  def hash
    @from.hash ^ @to.hash
  end

  def eql?(o)
    self.class == o.class && @from == o.numeric_from && @to == o.numeric_to
  end

  def instance?(o, guard = nil)
    (o.is_a?(Float) || o.is_a?(Integer)) && o >= @from && o <= @to
  end

  def unbounded?
    @from == -Float::INFINITY && @to == Float::INFINITY
  end

  protected

  # @api_private
  def _assignable?(o, guard)
    return false unless o.is_a?(self.class)
    # If o min and max are within the range of t
    @from <= o.numeric_from && @to >= o.numeric_to
  end

  DEFAULT = PNumericType.new(-Float::INFINITY)
end

# @api public
#
class PIntegerType < PNumericType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'NumericType')
  end

  # Will respond `true` for any range that is bounded at both ends.
  #
  # @return [Boolean] `true` if the type describes a finite range.
  def finite_range?
    @from != -Float::INFINITY && @to != Float::INFINITY
  end

  def generalize
    DEFAULT
  end

  def instance?(o, guard = nil)
    o.is_a?(Integer) && o >= numeric_from && o <= numeric_to
  end

  # Checks if this range is adjacent to the given range
  #
  # @param o [PIntegerType] the range to compare with
  # @return [Boolean] `true` if this range is adjacent to the other range
  # @api public
  def adjacent?(o)
    o.is_a?(PIntegerType) &&  (@to + 1 == o.from || o.to + 1 == @from)
  end

  # Concatenates this range with another range provided that the ranges intersect or
  # are adjacent. When that's not the case, this method will return `nil`
  #
  # @param o [PIntegerType] the range to concatenate with this range
  # @return [PIntegerType,nil] the concatenated range or `nil` when the ranges were apart
  # @api public
  def merge(o)
    if intersect?(o) || adjacent?(o)
      min = @from <= o.numeric_from ? @from : o.numeric_from
      max = @to >= o.numeric_to ? @to : o.numeric_to
      PIntegerType.new(min, max)
    else
      nil
    end
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    # It's unknown if the iterable will be a range (min, max) or a "times" (0, max)
    PIterableType.new(PIntegerType::DEFAULT)
  end

  # Returns Float.Infinity if one end of the range is unbound
  def size
    return Float::INFINITY if @from == -Float::INFINITY || @to == Float::INFINITY
    1+(to-from).abs
  end

  # Returns the range as an array ordered so the smaller number is always first.
  # The number may be Infinity or -Infinity.
  def range
    [@from, @to]
  end

  # Returns Enumerator if no block is given
  # Returns nil if size is infinity (does not yield)
  def each(&block)
    r = Iterable.on(self)
    block_given? ? r.each(&block) : r
  end

  # Returns a range where both to and from are positive numbers. Negative
  # numbers are converted to zero
  # @return [PIntegerType] a positive range
  def to_size
    @from >= 0 ? self : PIntegerType.new(0, @to < 0 ? 0 : @to)
  end

  def new_function
    @@new_function ||= Puppet::Functions.create_loaded_function(:new, loader) do
      local_types do
        type 'Radix       = Variant[Default, Integer[2,2], Integer[8,8], Integer[10,10], Integer[16,16]]'
        type "Convertible = Variant[Numeric, Boolean, Pattern[/#{INTEGER_PATTERN}/], Timespan, Timestamp]"
        type 'NamedArgs   = Struct[{from => Convertible, Optional[radix] => Radix, Optional[abs] => Boolean}]'
      end

      dispatch :from_args do
        param          'Convertible',  :from
        optional_param 'Radix',   :radix
        optional_param 'Boolean', :abs
      end

      dispatch :from_hash do
        param          'NamedArgs',  :hash_args
      end

      argument_mismatch :on_error_hash do
        param          'Hash',  :hash_args
      end

      argument_mismatch :on_error do
        param          'Any',     :from
        optional_param 'Integer', :radix
        optional_param 'Boolean', :abs
      end

      def from_args(from, radix = :default, abs = false)
        result = from_convertible(from, radix)
        abs ? result.abs : result
      end

      def from_hash(args_hash)
        from_args(args_hash['from'], args_hash['radix'] || :default, args_hash['abs'] || false)
      end

      def from_convertible(from, radix)
        case from
        when Float, Time::TimeData
          from.to_i
        when Integer
          from
        when TrueClass
          1
        when FalseClass
          0
        else
          begin
            radix == :default ? Integer(from) : Integer(from, radix)
          rescue TypeError => e
            raise TypeConversionError.new(e.message)
          rescue ArgumentError => e
            # Test for special case where there is whitespace between sign and number
            match = Patterns::WS_BETWEEN_SIGN_AND_NUMBER.match(from)
            if match
              begin
                # Try again, this time with whitespace removed
                return from_args(match[1] + match[2], radix)
              rescue TypeConversionError
                # Ignored to retain original error
              end
            end
            raise TypeConversionError.new(e.message)
          end
        end
      end

      def on_error_hash(args_hash)
        if args_hash.include?('from')
          from = args_hash['from']
          return on_error(from) unless loader.load(:type, 'convertible').instance?(from)
        end
        radix = args_hash['radix']
        assert_radix(radix) unless radix.nil? || radix == :default
        TypeAsserter.assert_instance_of('Integer.new', loader.load(:type, 'namedargs'), args_hash)
      end

      def on_error(from, radix = :default, abs = nil)
        assert_radix(radix) unless radix == :default
        if from.is_a?(String)
          _("The string '%{str}' cannot be converted to Integer") % { str: from }
        else
          t = TypeCalculator.singleton.infer(from).generalize
          _("Value of type %{type} cannot be converted to Integer") % { type: t }
        end
      end

      def assert_radix(radix)
        case radix
        when 2, 8, 10, 16
        else
          raise ArgumentError.new(_("Illegal radix: %{radix}, expected 2, 8, 10, 16, or default") % { radix: radix })
        end
        radix
      end

    end
  end

  DEFAULT = PIntegerType.new(-Float::INFINITY)
end

# @api public
#
class PFloatType < PNumericType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'NumericType')
  end

  def generalize
    DEFAULT
  end

  def instance?(o, guard = nil)
    o.is_a?(Float) && o >= numeric_from && o <= numeric_to
  end

  # Concatenates this range with another range provided that the ranges intersect. When that's not the case, this
  # method will return `nil`
  #
  # @param o [PFloatType] the range to concatenate with this range
  # @return [PFloatType,nil] the concatenated range or `nil` when the ranges were apart
  # @api public
  def merge(o)
    if intersect?(o)
      min = @from <= o.from ? @from : o.from
      max = @to >= o.to ? @to : o.to
      PFloatType.new(min, max)
    else
      nil
    end
  end

  # Returns a new function that produces a Float value
  #
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_float, type.loader) do
      local_types do
        type "Convertible = Variant[Numeric, Boolean, Pattern[/#{FLOAT_PATTERN}/], Timespan, Timestamp]"
        type 'NamedArgs   = Struct[{from => Convertible, Optional[abs] => Boolean}]'
      end

      dispatch :from_args do
        param          'Convertible',  :from
        optional_param 'Boolean',      :abs
      end

      dispatch :from_hash do
        param          'NamedArgs',  :hash_args
      end

      argument_mismatch :on_error do
        param          'Any',     :from
        optional_param 'Boolean', :abs
      end

      def from_args(from, abs = false)
        result = from_convertible(from)
        abs ? result.abs : result
      end

      def from_hash(args_hash)
        from_args(args_hash['from'], args_hash['abs'] || false)
      end

      def from_convertible(from)
        case from
        when Float
          from
        when Integer
          Float(from)
        when Time::TimeData
          from.to_f
        when TrueClass
          1.0
        when FalseClass
          0.0
        else
          begin
            # support a binary as float
            if from[0] == '0' && from[1].downcase == 'b'
              from = Integer(from)
            end
            Float(from)
          rescue TypeError => e
            raise TypeConversionError.new(e.message)
          rescue ArgumentError => e
            # Test for special case where there is whitespace between sign and number
            match = Patterns::WS_BETWEEN_SIGN_AND_NUMBER.match(from)
            if match
              begin
                # Try again, this time with whitespace removed
                return from_args(match[1] + match[2])
              rescue TypeConversionError
                # Ignored to retain original error
              end
            end
            raise TypeConversionError.new(e.message)
          end
        end
      end

      def on_error(from, _ = false)
        if from.is_a?(String)
          _("The string '%{str}' cannot be converted to Float") % { str: from }
        else
          t = TypeCalculator.singleton.infer(from).generalize
          _("Value of type %{type} cannot be converted to Float") % { type: t }
        end
      end
    end
  end

  DEFAULT = PFloatType.new(-Float::INFINITY)
end

# @api public
#
class PCollectionType < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'size_type' => {
        KEY_TYPE => POptionalType.new(PTypeType.new(PIntegerType::DEFAULT)),
        KEY_VALUE => nil
      }
    )
  end

  attr_reader :size_type

  def initialize(size_type)
    @size_type = size_type.nil? ? nil : size_type.to_size
  end

  def accept(visitor, guard)
    super
    @size_type.accept(visitor, guard) unless @size_type.nil?
  end

  def generalize
    DEFAULT
  end

  def normalize(guard = nil)
    DEFAULT
  end

  def instance?(o, guard = nil)
    # The inferred type of a class derived from Array or Hash is either Runtime or Object. It's not assignable to the Collection type.
    if o.instance_of?(Array) || o.instance_of?(Hash)
      @size_type.nil? || @size_type.instance?(o.size)
    else
      false
    end
  end

  # Returns an array with from (min) size to (max) size
  def size_range
    (@size_type || DEFAULT_SIZE).range
  end

  def has_empty_range?
    from, to = size_range
    from == 0 && to == 0
  end

  def hash
    @size_type.hash
  end

  def iterable?(guard = nil)
    true
  end

  def eql?(o)
    self.class == o.class && @size_type == o.size_type
  end


  DEFAULT_SIZE = PIntegerType.new(0)
  ZERO_SIZE = PIntegerType.new(0, 0)
  NOT_EMPTY_SIZE = PIntegerType.new(1)
  DEFAULT = PCollectionType.new(nil)

  protected

  # @api private
  #
  def _assignable?(o, guard)
    case o
      when PCollectionType
        (@size_type || DEFAULT_SIZE).assignable?(o.size_type || DEFAULT_SIZE, guard)
      when PTupleType
        # compute the tuple's min/max size, and check if that size matches
        size_s = size_type || DEFAULT_SIZE
        size_o = o.size_type
        if size_o.nil?
          type_count = o.types.size
          size_o = PIntegerType.new(type_count, type_count)
        end
        size_s.assignable?(size_o)
      when PStructType
        from = to = o.elements.size
        (@size_type || DEFAULT_SIZE).assignable?(PIntegerType.new(from, to), guard)
      else
        false
    end
  end
end

class PIterableType < PTypeWithContainedType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => nil
      }
    )
  end

  def element_type
    @type
  end

  def instance?(o, guard = nil)
    if @type.nil? || @type.assignable?(PAnyType::DEFAULT, guard)
      # Any element_type will do
      case o
      when Iterable, String, Hash, Array, Range, PEnumType
        true
      when Integer
        o >= 0
      when PIntegerType
        o.finite_range?
      when PTypeAliasType
        instance?(o.resolved_type, guard)
      else
        false
      end
    else
      assignable?(TypeCalculator.infer(o), guard)
    end
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    self
  end

  DEFAULT = PIterableType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    if @type.nil? || @type.assignable?(PAnyType::DEFAULT, guard)
      # Don't request the iterable_type. Since this Iterable accepts Any element, it is enough that o is iterable.
      o.iterable?
    else
      o = o.iterable_type
      o.nil? || o.element_type.nil? ? false : @type.assignable?(o.element_type, guard)
    end
  end
end

# @api public
#
class PIteratorType < PTypeWithContainedType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => nil
      }
    )
  end

  def element_type
    @type
  end

  def instance?(o, guard = nil)
    o.is_a?(Iterable) && (@type.nil? || @type.assignable?(o.element_type, guard))
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    @type.nil? ? PIterableType::DEFAULT : PIterableType.new(@type)
  end

  DEFAULT = PIteratorType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    o.is_a?(PIteratorType) && (@type.nil? || @type.assignable?(o.element_type, guard))
  end
end

# @api public
#
class PStringType < PScalarDataType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarDataType',
      'size_type_or_value' => {
        KEY_TYPE => POptionalType.new(PVariantType.new([PStringType::DEFAULT, PTypeType.new(PIntegerType::DEFAULT)])),
      KEY_VALUE => nil
    })
  end

  attr_reader :size_type_or_value

  def initialize(size_type_or_value, deprecated_multi_args = EMPTY_ARRAY)
    unless deprecated_multi_args.empty?
      if Puppet[:strict] != :off
        #TRANSLATORS 'PStringType#initialize' is a class and method name and should not be translated
        Puppet.warn_once('deprecations', "PStringType#initialize_multi_args",
                         _("Passing more than one argument to PStringType#initialize is deprecated"))
      end
      size_type_or_value = deprecated_multi_args[0]
    end
    @size_type_or_value = size_type_or_value.is_a?(PIntegerType) ? size_type_or_value.to_size : size_type_or_value
  end

  def accept(visitor, guard)
    super
    @size_type_or_value.accept(visitor, guard) if @size_type_or_value.is_a?(PIntegerType)
  end

  def generalize
    DEFAULT
  end

  def hash
    @size_type_or_value.hash
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    ITERABLE_TYPE
  end

  def eql?(o)
    self.class == o.class && @size_type_or_value == o.size_type_or_value
  end

  def instance?(o, guard = nil)
    # true if size compliant
    if o.is_a?(String)
      if @size_type_or_value.is_a?(PIntegerType)
        @size_type_or_value.instance?(o.size, guard)
      else
        @size_type_or_value.nil? ? true : o == value
      end
    else
      false
    end
  end

  def value
    @size_type_or_value.is_a?(PIntegerType) ? nil : @size_type_or_value
  end

  # @deprecated
  # @api private
  def values
    if Puppet[:strict] != :off
      #TRANSLATORS 'PStringType#values' and '#value' are classes and method names and should not be translated
      Puppet.warn_once('deprecations', "PStringType#values", _("Method PStringType#values is deprecated. Use #value instead"))
    end
    @value.is_a?(String) ? [@value] : EMPTY_ARRAY
  end

  def size_type
    @size_type_or_value.is_a?(PIntegerType) ? @size_type_or_value : nil
  end

  def derived_size_type
    if @size_type_or_value.is_a?(PIntegerType)
      @size_type_or_value
    elsif @size_type_or_value.is_a?(String)
      sz = @size_type_or_value.size
      PIntegerType.new(sz, sz)
    else
      PCollectionType::DEFAULT_SIZE
    end
  end

  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_string, type.loader) do
      local_types do
        type "Format = Pattern[/#{StringConverter::Format::FMT_PATTERN_STR}/]"
        type 'ContainerFormat = Struct[{
          Optional[format]         => Format,
          Optional[separator]      => String,
          Optional[separator2]     => String,
          Optional[string_formats] => Hash[Type, Format]
        }]'
        type 'TypeMap = Hash[Type, Variant[Format, ContainerFormat]]'
        type 'Convertible = Any'
        type 'Formats = Variant[Default, String[1], TypeMap]'
      end

      dispatch :from_args do
        param           'Convertible',  :from
        optional_param  'Formats',      :string_formats
      end

      def from_args(from, formats = :default)
        StringConverter.singleton.convert(from, formats)
      end
    end
  end

  DEFAULT = PStringType.new(nil)
  NON_EMPTY = PStringType.new(PCollectionType::NOT_EMPTY_SIZE)

  # Iterates over each character of the string
  ITERABLE_TYPE = PIterableType.new(PStringType.new(PIntegerType.new(1,1)))

  protected

  # @api private
  def _assignable?(o, guard)
    if @size_type_or_value.is_a?(PIntegerType)
      # A general string is assignable by any other string or pattern restricted string
      # if the string has a size constraint it does not match since there is no reasonable way
      # to compute the min/max length a pattern will match. For enum, it is possible to test that
      # each enumerator value is within range
      case o
      when PStringType
        @size_type_or_value.assignable?(o.derived_size_type, guard)

      when PEnumType
        if o.values.empty?
          # enum represents all enums, and thus all strings, a sized constrained string can thus not
          # be assigned any enum (unless it is max size).
          @size_type_or_value.assignable?(PCollectionType::DEFAULT_SIZE, guard)
        else
          # true if all enum values are within range
          orange = o.values.map(&:size).minmax
          srange = @size_type_or_value.range
          # If o min and max are within the range of t
          srange[0] <= orange[0] && srange[1] >= orange[1]
        end

      when PPatternType
        # true if size constraint is at least 0 to +Infinity (which is the same as the default)
        @size_type_or_value.assignable?(PCollectionType::DEFAULT_SIZE, guard)
      else
        # no other type matches string
        false
      end
    else
      case o
      when PStringType
        # Must match exactly when value is a string
        @size_type_or_value.nil? || @size_type_or_value == o.size_type_or_value
      when PEnumType
        @size_type_or_value.nil? ? true : o.values.size == 1 && !o.case_insensitive? && o.values[0]
      when PPatternType
        @size_type_or_value.nil?
      else
        # All others are false, since no other type describes the same set of specific strings
        false
      end
    end
  end
end

# @api public
#
class PRegexpType < PScalarType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarType',
      'pattern' => {
        KEY_TYPE => PVariantType.new([PUndefType::DEFAULT, PStringType::DEFAULT, PRegexpType::DEFAULT]),
        KEY_VALUE => nil
      })
  end


  # Returns a new function that produces a Regexp instance
  #
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_float, type.loader) do
      dispatch :from_string do
        param 'String', :pattern
      end

      def from_string(pattern)
        Regexp.new(pattern)
      end
    end
  end

  attr_reader :pattern

  # @param regexp [Regexp] the regular expression
  # @return [String] the Regexp as a slash delimited string with slashes escaped
  def self.regexp_to_s_with_delimiters(regexp)
    regexp.options == 0 ? regexp.inspect : "/#{regexp.to_s}/"
  end

  # @param regexp [Regexp] the regular expression
  # @return [String] the Regexp as a string without escaped slash
  def self.regexp_to_s(regexp)
    # Rubies < 2.0.0 retains escaped delimiters in the source string.
    @source_retains_escaped_slash ||= Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new('2.0.0')
    source = regexp.source
    if @source_retains_escaped_slash && source.include?('\\')
      # Restore corrupt string in rubies <2.0.0, i.e. turn '\/' into '/' but
      # don't touch valid escapes such as '\s', '\{' etc.
      escaped = false
      bld = ''
      source.each_codepoint do |codepoint|
        if escaped
          bld << 0x5c unless codepoint == 0x2f # '/'
          bld << codepoint
          escaped = false
        elsif codepoint == 0x5c # '\'
          escaped = true
        elsif codepoint <= 0x7f
          bld << codepoint
        else
          bld << [codepoint].pack('U')
        end
      end
      source = bld
    end
    append_flags_group(source, regexp.options)
  end

  def self.append_flags_group(rx_string, options)
    if options == 0
      rx_string
    else
      bld = '(?'
      bld << 'i' if (options & Regexp::IGNORECASE) != 0
      bld << 'm' if (options & Regexp::MULTILINE) != 0
      bld << 'x' if (options & Regexp::EXTENDED) != 0
      unless options == (Regexp::IGNORECASE | Regexp::MULTILINE | Regexp::EXTENDED)
        bld << '-'
        bld << 'i' if (options & Regexp::IGNORECASE) == 0
        bld << 'm' if (options & Regexp::MULTILINE) == 0
        bld << 'x' if (options & Regexp::EXTENDED) == 0
      end
      bld << ':' << rx_string << ')'
      bld.freeze
    end
  end

  def initialize(pattern)
    if pattern.is_a?(Regexp)
      @regexp = pattern
      @pattern = PRegexpType.regexp_to_s(pattern)
    else
      @pattern = pattern
    end
  end

  def regexp
    @regexp ||= Regexp.new(@pattern || '')
  end

  def hash
    @pattern.hash
  end

  def eql?(o)
    self.class == o.class && @pattern == o.pattern
  end

  def instance?(o, guard=nil)
    o.is_a?(Regexp) && @pattern.nil? || regexp == o
  end

  DEFAULT = PRegexpType.new(nil)

  protected

  # @api private
  #
  def _assignable?(o, guard)
    o.is_a?(PRegexpType) && (@pattern.nil? || @pattern == o.pattern)
  end
end

# Represents a subtype of String that narrows the string to those matching the patterns
# If specified without a pattern it is basically the same as the String type.
#
# @api public
#
class PPatternType < PScalarDataType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarDataType', 'patterns' => PArrayType.new(PRegexpType::DEFAULT))
  end

  attr_reader :patterns

  def initialize(patterns)
    @patterns = patterns.freeze
  end

  def accept(visitor, guard)
    super
    @patterns.each { |p| p.accept(visitor, guard) }
  end

  def hash
    @patterns.hash
  end

  def eql?(o)
    self.class == o.class && @patterns.size == o.patterns.size && (@patterns - o.patterns).empty?
  end

  def instance?(o, guard = nil)
    o.is_a?(String) && (@patterns.empty? || @patterns.any? { |p| p.regexp.match(o) })
  end

  DEFAULT = PPatternType.new(EMPTY_ARRAY)

  protected

  # @api private
  #
  def _assignable?(o, guard)
    return true if self == o
    case o
    when PStringType
      v = o.value
      if v.nil?
        # Strings cannot all match a pattern, but if there is no pattern it is ok
        # (There should really always be a pattern, but better safe than sorry).
        @patterns.empty?
      else
        # the string in String type must match one of the patterns in Pattern type,
        # or Pattern represents all Patterns == all Strings
        regexps = @patterns.map { |p| p.regexp }
        regexps.empty? || regexps.any? { |re| re.match(v) }
      end
    when PEnumType
      if o.values.empty?
        # Enums (unknown which ones) cannot all match a pattern, but if there is no pattern it is ok
        # (There should really always be a pattern, but better safe than sorry).
        @patterns.empty?
      else
        # all strings in String/Enum type must match one of the patterns in Pattern type,
        # or Pattern represents all Patterns == all Strings
        regexps = @patterns.map { |p| p.regexp }
        regexps.empty? || o.values.all? { |s| regexps.any? {|re| re.match(s) } }
      end
    when PPatternType
      @patterns.empty?
    else
      false
    end
  end
end

# @api public
#
class PBooleanType < PScalarDataType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarDataType')
  end

  attr_reader :value

  def initialize(value = nil)
    @value = value
  end

  def eql?(o)
    o.is_a?(PBooleanType) && @value == o.value
  end

  def generalize
    PBooleanType::DEFAULT
  end

  def hash
    31 ^ @value.hash
  end

  def instance?(o, guard = nil)
    (o == true || o == false) && (@value.nil? || value == o)
  end

  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_boolean, type.loader) do
      dispatch :from_args do
        param "Variant[Integer, Float, Boolean, Enum['false','true','yes','no','y','n',true]]",  :from
      end

      argument_mismatch :on_error do
        param  'Any', :from
      end

      def from_args(from)
        from = from.downcase if from.is_a?(String)
        case from
        when Float
          from != 0.0
        when Integer
          from != 0
        when false, 'false', 'no', 'n'
          false
        else
          true
        end
      end

      def on_error(from)
        if from.is_a?(String)
          _("The string '%{str}' cannot be converted to Boolean") % { str: from }
        else
          t = TypeCalculator.singleton.infer(from).generalize
          _("Value of type %{type} cannot be converted to Boolean") % { type: t }
        end
      end
    end
  end

  DEFAULT = PBooleanType.new
  TRUE = PBooleanType.new(true)
  FALSE = PBooleanType.new(false)

  protected

  # @api private
  #
  def _assignable?(o, guard)
    o.is_a?(PBooleanType) && (@value.nil? || @value == o.value)
  end
end

# @api public
#
# @api public
#
class PStructElement < TypedModelObject
  def self.register_ptype(loader, ir)
    @type = Pcore::create_object_type(loader, ir, self, 'Pcore::StructElement'.freeze, nil,
      'key_type' => PTypeType::DEFAULT,
      'value_type' => PTypeType::DEFAULT)
  end

  attr_accessor :key_type, :value_type

  def accept(visitor, guard)
    @key_type.accept(visitor, guard)
    @value_type.accept(visitor, guard)
  end

  def hash
    value_type.hash ^ key_type.hash
  end

  def name
    k = key_type
    k = k.optional_type if k.is_a?(POptionalType)
    k.value
  end

  def initialize(key_type, value_type)
    @key_type = key_type
    @value_type = value_type
  end

  def generalize
    gv_type = @value_type.generalize
    @value_type.equal?(gv_type) ? self : PStructElement.new(@key_type, gv_type)
  end

  def normalize(guard = nil)
    nv_type = @value_type.normalize(guard)
    @value_type.equal?(nv_type) ? self : PStructElement.new(@key_type, nv_type)
  end

  def resolve(loader)
    rkey_type = @key_type.resolve(loader)
    rvalue_type = @value_type.resolve(loader)
    rkey_type.equal?(@key_type) && rvalue_type.equal?(@value_type) ? self : self.class.new(rkey_type, rvalue_type)
  end

  def <=>(o)
    self.name <=> o.name
  end

  def eql?(o)
    self == o
  end

  def ==(o)
    self.class == o.class && value_type == o.value_type && key_type == o.key_type
  end

  # Special boostrap method to overcome the hen and egg problem with the Object initializer that contains
  # types that are derived from Object (such as Annotation)
  #
  # @api private
  def replace_value_type(new_type)
    @value_type = new_type
  end
end

# @api public
#
class PStructType < PAnyType
  include Enumerable

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType', 'elements' => PArrayType.new(PTypeReferenceType.new('Pcore::StructElement')))
  end

  def initialize(elements)
    @elements = elements.freeze
  end

  def accept(visitor, guard)
    super
    @elements.each { |elem| elem.accept(visitor, guard) }
  end

  def each
    if block_given?
      elements.each { |elem| yield elem }
    else
      elements.to_enum
    end
  end

  def generalize
    if @elements.empty?
      DEFAULT
    else
      alter_type_array(@elements, :generalize) { |altered| PStructType.new(altered) }
    end
  end

  def normalize(guard = nil)
    if @elements.empty?
      DEFAULT
    else
      alter_type_array(@elements, :normalize, guard) { |altered| PStructType.new(altered) }
    end
  end

  def hashed_elements
    @hashed ||= @elements.reduce({}) {|memo, e| memo[e.name] = e; memo }
  end

  def hash
    @elements.hash
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    if self == DEFAULT
      PIterableType.new(PHashType::DEFAULT_KEY_PAIR_TUPLE)
    else
      PIterableType.new(
        PTupleType.new([
          PVariantType.maybe_create(@elements.map {|se| se.key_type }),
          PVariantType.maybe_create(@elements.map {|se| se.value_type })],
          PHashType::KEY_PAIR_TUPLE_SIZE))
    end
  end

  def resolve(loader)
    changed = false
    relements = @elements.map do |elem|
      relem = elem.resolve(loader)
      changed ||= !relem.equal?(elem)
      relem
    end
    changed ? self.class.new(relements) : self
  end

  def eql?(o)
    self.class == o.class && @elements == o.elements
  end

  def elements
    @elements
  end

  def instance?(o, guard = nil)
    # The inferred type of a class derived from Hash is either Runtime or Object. It's not assignable to the Struct type.
    return false unless o.instance_of?(Hash)
    matched = 0
    @elements.all? do |e|
      key = e.name
      v = o[key]
      if v.nil? && !o.include?(key)
        # Entry is missing. Only OK when key is optional
        e.key_type.assignable?(PUndefType::DEFAULT, guard)
      else
        matched += 1
        e.value_type.instance?(v, guard)
      end
    end && matched == o.size
  end

  def new_function
    # Simply delegate to Hash type and let the higher level assertion deal with
    # compliance with the Struct type regarding the produced result.
    PHashType.new_function(self)
  end

  DEFAULT = PStructType.new(EMPTY_ARRAY)

  protected

  # @api private
  def _assignable?(o, guard)
    if o.is_a?(Types::PStructType)
      h2 = o.hashed_elements
      matched = 0
      elements.all? do |e1|
        e2 = h2[e1.name]
        if e2.nil?
          e1.key_type.assignable?(PUndefType::DEFAULT, guard)
        else
          matched += 1
          e1.key_type.assignable?(e2.key_type, guard) && e1.value_type.assignable?(e2.value_type, guard)
        end
      end && matched == h2.size
    elsif o.is_a?(Types::PHashType)
      required = 0
      required_elements_assignable = elements.all? do |e|
        key_type = e.key_type
        if key_type.assignable?(PUndefType::DEFAULT)
          # Element is optional so Hash does not need to provide it
          true
        else
          required += 1
          if e.value_type.assignable?(o.value_type, guard)
            # Hash must have something that is assignable. We don't care about the name or size of the key though
            # because we have no instance of a hash to compare against.
            key_type.generalize.assignable?(o.key_type)
          else
            false
          end
        end
      end
      if required_elements_assignable
        size_o = o.size_type || PCollectionType::DEFAULT_SIZE
        PIntegerType.new(required, elements.size).assignable?(size_o, guard)
      else
        false
      end
    else
      false
    end
  end
end

# @api public
#
class PTupleType < PAnyType
  include Enumerable

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'types' => PArrayType.new(PTypeType::DEFAULT),
      'size_type' => {
        KEY_TYPE => POptionalType.new(PTypeType.new(PIntegerType::DEFAULT)),
        KEY_VALUE => nil
      }
    )
  end

  # If set, describes min and max required of the given types - if max > size of
  # types, the last type entry repeats
  #
  attr_reader :size_type

  attr_reader :types

  def accept(visitor, guard)
    super
    @size_type.accept(visitor, guard) unless @size_type.nil?
    @types.each { |elem| elem.accept(visitor, guard) }
  end

  # @api private
  def callable_args?(callable_t, guard)
    unless size_type.nil?
      raise ArgumentError, 'Callable tuple may not have a size constraint when used as args'
    end

    params_tuple = callable_t.param_types
    param_block_t = callable_t.block_type
    arg_types = @types
    arg_block_t = arg_types.last
    if arg_block_t.kind_of_callable?(true, guard)
      # Can't pass a block to a callable that doesn't accept one
      return false if param_block_t.nil?

      # Check that the block is of the right tyṕe
      return false unless param_block_t.assignable?(arg_block_t, guard)

      # Check other arguments
      arg_count = arg_types.size - 1
      params_size_t = params_tuple.size_type || PIntegerType.new(*params_tuple.size_range)
      return false unless params_size_t.assignable?(PIntegerType.new(arg_count, arg_count), guard)

      ctypes = params_tuple.types
      arg_count.times do |index|
        return false unless (ctypes[index] || ctypes[-1]).assignable?(arg_types[index], guard)
      end
      return true
    end

    # Check that tuple is assignable and that the block (if declared) is optional
    params_tuple.assignable?(self, guard) && (param_block_t.nil? || param_block_t.assignable?(PUndefType::DEFAULT, guard))
  end

  def initialize(types, size_type = nil)
    @types = types
    @size_type = size_type.nil? ? nil : size_type.to_size
  end

  # Returns Enumerator for the types if no block is given, otherwise, calls the given
  # block with each of the types in this tuple
  def each
    if block_given?
      types.each { |x| yield x }
    else
      types.to_enum
    end
  end

  def generalize
    if self == DEFAULT
      DEFAULT
    else
      alter_type_array(@types, :generalize) { |altered_types| PTupleType.new(altered_types, @size_type) }
    end
  end

  def normalize(guard = nil)
    if self == DEFAULT
      DEFAULT
    else
      alter_type_array(@types, :normalize, guard) { |altered_types| PTupleType.new(altered_types, @size_type) }
    end
  end

  def resolve(loader)
    changed = false
    rtypes = @types.map do |type|
      rtype = type.resolve(loader)
      changed ||= !rtype.equal?(type)
      rtype
    end
    changed ? self.class.new(rtypes, @size_type) : self
  end

  def instance?(o, guard = nil)
    # The inferred type of a class derived from Array is either Runtime or Object. It's not assignable to the Tuple type.
    return false unless o.instance_of?(Array)
    if @size_type
      return false unless @size_type.instance?(o.size, guard)
    else
      return false unless @types.empty? || @types.size == o.size
    end
    index = -1
    @types.empty? || o.all? do |element|
      @types.fetch(index += 1) { @types.last }.instance?(element, guard)
    end
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    PIterableType.new(PVariantType.maybe_create(types))
  end

  # Returns the number of elements accepted [min, max] in the tuple
  def size_range
    if @size_type.nil?
      types_size = @types.size
      types_size == 0 ? [0, Float::INFINITY] : [types_size, types_size]
    else
      @size_type.range
    end
  end

  # Returns the number of accepted occurrences [min, max] of the last type in the tuple
  # The defaults is [1,1]
  #
  def repeat_last_range
    if @size_type.nil?
      return [1, 1]
    end
    types_size = @types.size
    from, to = @size_type.range
    min = from - (types_size-1)
    min = min <= 0 ? 0 : min
    max = to - (types_size-1)
    [min, max]
  end

  def hash
    @size_type.hash ^ @types.hash
  end

  def eql?(o)
    self.class == o.class && @types == o.types && @size_type == o.size_type
  end

  def new_function
    # Simply delegate to Array type and let the higher level assertion deal with
    # compliance with the Tuple type regarding the produced result.
    PArrayType.new_function(self)
  end

  DEFAULT = PTupleType.new(EMPTY_ARRAY)

  protected

  # @api private
  def _assignable?(o, guard)
    return true if self == o
    return false unless o.is_a?(PTupleType) || o.is_a?(PArrayType)
    s_types = types
    size_s = size_type || PIntegerType.new(*size_range)

    if o.is_a?(PTupleType)
      size_o = o.size_type || PIntegerType.new(*o.size_range)
      return false unless size_s.assignable?(size_o, guard)
      unless s_types.empty?
        o_types = o.types
        return size_s.numeric_from == 0 if o_types.empty?
        o_types.size.times do |index|
          return false unless (s_types[index] || s_types[-1]).assignable?(o_types[index], guard)
        end
      end
    else
      size_o = o.size_type || PCollectionType::DEFAULT_SIZE
      return false unless size_s.assignable?(size_o, guard)
      unless s_types.empty?
        o_entry = o.element_type
        # Array of anything can not be assigned (unless tuple is tuple of anything) - this case
        # was handled at the top of this method.
        #
        return false if o_entry.nil?
        [s_types.size, size_o.range[1]].min.times { |index| return false unless (s_types[index] || s_types[-1]).assignable?(o_entry, guard) }
      end
    end
    true
  end
end

# @api public
#
class PCallableType < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'param_types' => {
        KEY_TYPE => POptionalType.new(PTypeType.new(PTupleType::DEFAULT)),
        KEY_VALUE => nil
      },
      'block_type' => {
        KEY_TYPE => POptionalType.new(PTypeType.new(PCallableType::DEFAULT)),
        KEY_VALUE => nil
      },
      'return_type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => PAnyType::DEFAULT
      }
    )
  end

  # @return [PAnyType] The type for the values returned by this callable. Returns `nil` if return value is unconstrained
  attr_reader :return_type

  # Types of parameters as a Tuple with required/optional count, or an Integer with min (required), max count
  # @return [PTupleType] the tuple representing the parameter types
  attr_reader :param_types

  # Although being an abstract type reference, only Callable, or all Callables wrapped in
  # Optional or Variant are supported
  # If not set, the meaning is that block is not supported.
  # @return [PAnyType|nil] the block type
  attr_reader :block_type

  # @param param_types [PTupleType]
  # @param block_type [PAnyType]
  # @param return_type [PAnyType]
  def initialize(param_types, block_type = nil, return_type = nil)
    @param_types = param_types
    @block_type = block_type
    @return_type = return_type == PAnyType::DEFAULT ? nil : return_type
  end

  def accept(visitor, guard)
    super
    @param_types.accept(visitor, guard) unless @param_types.nil?
    @block_type.accept(visitor, guard) unless @block_type.nil?
    @return_type.accept(visitor, guard) unless @return_type.nil?
  end

  def generalize
    if self == DEFAULT
      DEFAULT
    else
      params_t = @param_types.nil? ? nil : @param_types.generalize
      block_t = @block_type.nil? ? nil : @block_type.generalize
      return_t = @return_type.nil? ? nil : @return_type.generalize
      @param_types.equal?(params_t) && @block_type.equal?(block_t) && @return_type.equal?(return_t) ? self : PCallableType.new(params_t, block_t, return_t)
    end
  end

  def normalize(guard = nil)
    if self == DEFAULT
      DEFAULT
    else
      params_t = @param_types.nil? ? nil : @param_types.normalize(guard)
      block_t = @block_type.nil? ? nil : @block_type.normalize(guard)
      return_t = @return_type.nil? ? nil : @return_type.normalize(guard)
      @param_types.equal?(params_t) && @block_type.equal?(block_t) && @return_type.equal?(return_t) ? self : PCallableType.new(params_t, block_t, return_t)
    end
  end

  def instance?(o, guard = nil)
    (o.is_a?(Proc) || o.is_a?(Evaluator::Closure) || o.is_a?(Functions::Function)) && assignable?(TypeCalculator.infer(o), guard)
  end

  # Returns `true` if this instance is a callable that accepts the given _args_
  #
  # @param args [Array] the arguments to test
  # @return [Boolean] `true` if this instance is a callable that accepts the given _args_
  def callable_with?(args, block = nil)
    # nil param_types and compatible return type means other Callable is assignable
    return true if @param_types.nil?
    return false unless @param_types.instance?(args)
    if @block_type.nil?
      block == nil
    else
      @block_type.instance?(block)
    end
  end

  # @api private
  def callable_args?(required_callable_t, guard)
    # If the required callable is equal or more specific than self, self is acceptable arguments
    required_callable_t.assignable?(self, guard)
  end

  def kind_of_callable?(optional=true, guard = nil)
    true
  end

  # Returns the number of accepted arguments [min, max]
  def size_range
    @param_types.nil? ? nil : @param_types.size_range
  end

  # Returns the number of accepted arguments for the last parameter type [min, max]
  #
  def last_range
    @param_types.nil? ? nil : @param_types.repeat_last_range
  end

  # Range [0,0], [0,1], or [1,1] for the block
  #
  def block_range
    case block_type
    when POptionalType
      [0,1]
    when PVariantType, PCallableType
      [1,1]
    else
      [0,0]
    end
  end

  def hash
    [@param_types, @block_type, @return_type].hash
  end

  def eql?(o)
    self.class == o.class && @param_types == o.param_types && @block_type == o.block_type && @return_type == o.return_type
  end

  def resolve(loader)
    params_t = @param_types.nil? ? nil : @param_types.resolve(loader)
    block_t = @block_type.nil? ? nil : @block_type.resolve(loader)
    return_t = @return_type.nil? ? nil : @return_type.resolve(loader)
    @param_types.equal?(params_t) && @block_type.equal?(block_t) && @return_type.equal?(return_t) ? self : self.class.new(params_t, block_t, return_t)
  end

  DEFAULT = PCallableType.new(nil, nil, nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PCallableType)
    return false unless @return_type.nil? || @return_type.assignable?(o.return_type || PAnyType::DEFAULT, guard)

    # nil param_types and compatible return type means other Callable is assignable
    return true if @param_types.nil?

    # NOTE: these tests are made in reverse as it is calling the callable that is constrained
    # (it's lower bound), not its upper bound
    other_param_types = o.param_types

    return false if other_param_types.nil? ||  !other_param_types.assignable?(@param_types, guard)
    # names are ignored, they are just information
    # Blocks must be compatible
    this_block_t = @block_type || PUndefType::DEFAULT
    that_block_t = o.block_type || PUndefType::DEFAULT
    that_block_t.assignable?(this_block_t, guard)
  end
end

# @api public
#
class PArrayType < PCollectionType

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'CollectionType',
      'element_type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => PAnyType::DEFAULT
      }
    )
  end

  attr_reader :element_type

  def initialize(element_type, size_type = nil)
    super(size_type)
    if !size_type.nil? && size_type.from == 0 && size_type.to == 0
      @element_type = PUnitType::DEFAULT
    else
      @element_type = element_type.nil? ? PAnyType::DEFAULT : element_type
    end
  end

  def accept(visitor, guard)
    super
    @element_type.accept(visitor, guard)
  end

  # @api private
  def callable_args?(callable, guard = nil)
    param_t = callable.param_types
    block_t = callable.block_type
    # does not support calling with a block, but have to check that callable is ok with missing block
    (param_t.nil? || param_t.assignable?(self, guard)) && (block_t.nil? || block_t.assignable?(PUndefType::DEFAULT, guard))
  end

  def generalize
    if PAnyType::DEFAULT.eql?(@element_type)
      DEFAULT
    else
      ge_type = @element_type.generalize
      @size_type.nil? && @element_type.equal?(ge_type) ? self : self.class.new(ge_type, nil)
    end
  end

  def eql?(o)
    super && @element_type == o.element_type
  end

  def hash
    super ^ @element_type.hash
  end

  def normalize(guard = nil)
    if PAnyType::DEFAULT.eql?(@element_type)
      DEFAULT
    else
      ne_type = @element_type.normalize(guard)
      @element_type.equal?(ne_type) ? self : self.class.new(ne_type, @size_type)
    end
  end

  def resolve(loader)
    relement_type = @element_type.resolve(loader)
    relement_type.equal?(@element_type) ? self : self.class.new(relement_type, @size_type)
  end

  def instance?(o, guard = nil)
    # The inferred type of a class derived from Array is either Runtime or Object. It's not assignable to the Array type.
    return false unless o.instance_of?(Array)
    return false unless o.all? {|element| @element_type.instance?(element, guard) }
    size_t = size_type
    size_t.nil? || size_t.instance?(o.size, guard)
  end

  def iterable_type(guard = nil)
    PAnyType::DEFAULT.eql?(@element_type) ? PIterableType::DEFAULT : PIterableType.new(@element_type)
  end

  # Returns a new function that produces an Array
  #
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_array, type.loader) do

      dispatch :to_array do
        param           'Variant[Array,Hash,Binary,Iterable]', :from
        optional_param  'Boolean[false]', :wrap
      end

      dispatch :wrapped do
        param  'Any',           :from
        param  'Boolean[true]', :wrap
      end

      argument_mismatch :on_error do
        param  'Any',             :from
        optional_param 'Boolean', :wrap
      end

      def wrapped(from, _)
        from.is_a?(Array) ? from : [from]
      end

      def to_array(from, _ = false)
        case from
        when Array
          from
        when Hash
          from.to_a
        when PBinaryType::Binary
          # For older rubies, the #bytes method returns an Enumerator that must be rolled out
          from.binary_buffer.bytes.to_a
        else
          Iterable.on(from).to_a
        end
      end

      def on_error(from, _ = false)
        t = TypeCalculator.singleton.infer(from).generalize
        _("Value of type %{type} cannot be converted to Array") % { type: t }
      end
    end
  end

  DEFAULT = PArrayType.new(nil)
  EMPTY = PArrayType.new(PUnitType::DEFAULT, ZERO_SIZE)

  protected

  # Array is assignable if o is an Array and o's element type is assignable, or if o is a Tuple
  # @api private
  def _assignable?(o, guard)
    if o.is_a?(PTupleType)
      o_types = o.types
      size_s = size_type || DEFAULT_SIZE
      size_o = o.size_type
      if size_o.nil?
        type_count = o_types.size
        size_o = PIntegerType.new(type_count, type_count)
      end
      size_s.assignable?(size_o) && o_types.all? { |ot| @element_type.assignable?(ot, guard) }
    elsif o.is_a?(PArrayType)
      super && @element_type.assignable?(o.element_type, guard)
    else
      false
    end
  end
end

# @api public
#
class PHashType < PCollectionType

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'CollectionType',
      'key_type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => PAnyType::DEFAULT
      },
      'value_type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => PAnyType::DEFAULT
      }
    )
  end

  attr_accessor :key_type, :value_type

  def initialize(key_type, value_type, size_type = nil)
    super(size_type)
    if !size_type.nil? && size_type.from == 0 && size_type.to == 0
      @key_type = PUnitType::DEFAULT
      @value_type = PUnitType::DEFAULT
    else
      @key_type = key_type.nil? ? PAnyType::DEFAULT : key_type
      @value_type = value_type.nil? ? PAnyType::DEFAULT : value_type
    end
  end

  def accept(visitor, guard)
    super
    @key_type.accept(visitor, guard)
    @value_type.accept(visitor, guard)
  end

  def element_type
    if Puppet[:strict] != :off
      #TRANSLATOR 'Puppet::Pops::Types::PHashType#element_type' and '#value_type' are class and method names and should not be translated
      Puppet.warn_once('deprecations', 'Puppet::Pops::Types::PHashType#element_type',
        _('Puppet::Pops::Types::PHashType#element_type is deprecated, use #value_type instead'))
    end
    @value_type
  end

  def generalize
    if self == DEFAULT || self == EMPTY
      self
    else
      key_t = @key_type
      key_t = key_t.generalize
      value_t = @value_type
      value_t = value_t.generalize
      @size_type.nil? && @key_type.equal?(key_t) && @value_type.equal?(value_t) ? self : PHashType.new(key_t, value_t, nil)
    end
  end

  def normalize(guard = nil)
    if self == DEFAULT || self == EMPTY
      self
    else
      key_t = @key_type.normalize(guard)
      value_t = @value_type.normalize(guard)
      @size_type.nil? && @key_type.equal?(key_t) && @value_type.equal?(value_t) ? self : PHashType.new(key_t, value_t, @size_type)
    end
  end

  def hash
    super ^ @key_type.hash ^ @value_type.hash
  end

  def instance?(o, guard = nil)
    # The inferred type of a class derived from Hash is either Runtime or Object. It's not assignable to the Hash type.
    return false unless o.instance_of?(Hash)
    if o.keys.all? {|key| @key_type.instance?(key, guard) } && o.values.all? {|value| @value_type.instance?(value, guard) }
      size_t = size_type
      size_t.nil? || size_t.instance?(o.size, guard)
    else
      false
    end
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    if self == DEFAULT || self == EMPTY
      PIterableType.new(DEFAULT_KEY_PAIR_TUPLE)
    else
      PIterableType.new(PTupleType.new([@key_type, @value_type], KEY_PAIR_TUPLE_SIZE))
    end
  end

  def eql?(o)
    super && @key_type == o.key_type && @value_type == o.value_type
  end

  def is_the_empty_hash?
    self == EMPTY
  end

  def resolve(loader)
    rkey_type = @key_type.resolve(loader)
    rvalue_type = @value_type.resolve(loader)
    rkey_type.equal?(@key_type) && rvalue_type.equal?(@value_type) ? self : self.class.new(rkey_type, rvalue_type, @size_type)
  end

  def self.array_as_hash(value)
    return value unless value.is_a?(Array)
    result = {}
    value.each_with_index {|v, idx| result[idx] = array_as_hash(v) }
    result
  end

  # Returns a new function that produces a  Hash
  #
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_hash, type.loader) do
      local_types do
        type 'KeyValueArray = Array[Tuple[Any,Any],1]'
        type 'TreeArray = Array[Tuple[Array,Any],1]'
        type 'NewHashOption = Enum[tree, hash_tree]'
      end

      dispatch :from_tree do
        param           'TreeArray',       :from
        optional_param  'NewHashOption',   :build_option
      end

      dispatch :from_tuples do
        param           'KeyValueArray',  :from
      end

      dispatch :from_array do
        param           'Any',  :from
      end

      def from_tuples(tuple_array)
        Hash[tuple_array]
      end

      def from_tree(tuple_array, build_option = nil)
        if build_option.nil?
          return from_tuples(tuple_array)
        end
        # only remaining possible options is 'tree' or 'hash_tree'

        all_hashes = build_option == 'hash_tree'
        result = {}
        tuple_array.each do |entry|
          path = entry[0]
          value = entry[1]
          if path.empty?
            # root node (index [] was included - values merge into the result)
            # An array must be changed to a hash first as this is the root
            # (Cannot return an array from a Hash.new)
            if value.is_a?(Array)
              value.each_with_index {|v, idx| result[idx] = v }
            else
              result.merge!(value)
            end
          else
            r = path[0..-2].reduce(result) {|memo, idx| (memo.is_a?(Array) || memo.has_key?(idx)) ? memo[idx] : memo[idx] = {}}
            r[path[-1]]= (all_hashes ? PHashType.array_as_hash(value) : value)
          end
        end
        result
      end

      def from_array(from)
        case from
        when Array
          if from.size == 0
            {}
          else
            unless from.size % 2 == 0
              raise TypeConversionError.new(_('odd number of arguments for Hash'))
            end
            Hash[*from]
          end
        when Hash
          from
        else
          if PIterableType::DEFAULT.instance?(from)
            Hash[*Iterable.on(from).to_a]
          else
            t = TypeCalculator.singleton.infer(from).generalize
            raise TypeConversionError.new(_("Value of type %{type} cannot be converted to Hash") % { type: t })
          end
        end
      end
    end
  end

  DEFAULT = PHashType.new(nil, nil)
  KEY_PAIR_TUPLE_SIZE = PIntegerType.new(2,2)
  DEFAULT_KEY_PAIR_TUPLE = PTupleType.new([PUnitType::DEFAULT, PUnitType::DEFAULT], KEY_PAIR_TUPLE_SIZE)
  EMPTY = PHashType.new(PUnitType::DEFAULT, PUnitType::DEFAULT, PIntegerType.new(0, 0))

  protected

  # Hash is assignable if o is a Hash and o's key and element types are assignable
  # @api private
  def _assignable?(o, guard)
    case o
    when PHashType
      size_s = size_type
      return true if (size_s.nil? || size_s.from == 0) && o.is_the_empty_hash?
      return false unless @key_type.assignable?(o.key_type, guard) && @value_type.assignable?(o.value_type, guard)
      super
    when PStructType
      # hash must accept String as key type
      # hash must accept all value types
      # hash must accept the size of the struct
      o_elements = o.elements
      (size_type || DEFAULT_SIZE).instance?(o_elements.size, guard) &&
          o_elements.all? {|e| @key_type.instance?(e.name, guard) && @value_type.assignable?(e.value_type, guard) }
    else
      false
    end
  end
end

# A flexible type describing an any? of other types
# @api public
#
class PVariantType < PAnyType
  include Enumerable

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType', 'types' => PArrayType.new(PTypeType::DEFAULT))
  end

  attr_reader :types

  # Checks if the number of unique types in the given array is greater than one, and if so
  # creates a Variant with those types and returns it. If only one unique type is found,
  # that type is instead returned.
  #
  # @param types [Array<PAnyType>] the variants
  # @return [PAnyType] the resulting type
  # @api public
  def self.maybe_create(types)
    types = flatten_variants(types).uniq
    types.size == 1 ? types[0] : new(types)
  end

  # @param types [Array[PAnyType]] the variants
  def initialize(types)
    @types = types.freeze
  end

  def accept(visitor, guard)
    super
    @types.each { |t| t.accept(visitor, guard) }
  end

  def each
    if block_given?
      types.each { |t| yield t }
    else
      types.to_enum
    end
  end

  def generalize
    if self == DEFAULT
      self
    else
      alter_type_array(@types, :generalize) { |altered| PVariantType.maybe_create(altered) }
    end
  end

  def normalize(guard = nil)
    if self == DEFAULT || @types.empty?
      self
    else
      # Normalize all contained types
      modified = false
      types = alter_type_array(@types, :normalize, guard)
      if types == self
        types = @types
      else
        modified = true
      end

      if types.size == 1
        types[0]
      elsif types.any? { |t| t.is_a?(PUndefType) || t.is_a?(POptionalType) }
        # Undef entry present. Use an OptionalType with a normalized Variant without Undefs and Optional wrappers
        POptionalType.new(PVariantType.maybe_create(types.reject { |t| t.is_a?(PUndefType) }.map { |t| t.is_a?(POptionalType) ? t.type : t })).normalize
      else
        # Merge all variants into this one
        types = PVariantType.flatten_variants(types)
        size_before_merge = types.size

        types = swap_not_undefs(types)
        types = merge_enums(types)
        types = merge_patterns(types)
        types = merge_version_ranges(types)
        types = merge_numbers(PIntegerType, types)
        types = merge_numbers(PFloatType, types)
        types = merge_numbers(PTimespanType, types)
        types = merge_numbers(PTimestampType, types)

        if types.size == 1
          types[0]
        else
          modified || types.size != size_before_merge ? PVariantType.maybe_create(types) : self
        end
      end
    end
  end

  def self.flatten_variants(types)
    modified = false
    types = types.map do |t|
      if t.is_a?(PVariantType)
        modified = true
        t.types
      else
        t
      end
    end
    types.flatten! if modified
    types
  end

  def hash
    @types.hash
  end

  def instance?(o, guard = nil)
    # instance of variant if o is instance? of any of variant's types
    @types.any? { |type| type.instance?(o, guard) }
  end

  def really_instance?(o, guard = nil)
    @types.reduce(-1) do |memo, type|
      ri = type.really_instance?(o, guard)
      break ri if ri > 0
      ri > memo ? ri : memo
    end
  end

  def kind_of_callable?(optional = true, guard = nil)
    @types.all? { |type| type.kind_of_callable?(optional, guard) }
  end

  def eql?(o)
    self.class == o.class && @types.size == o.types.size && (@types - o.types).empty?
  end

  DEFAULT = PVariantType.new(EMPTY_ARRAY)

  def assignable?(o, guard = nil)
    # an empty Variant does not match Undef (it is void - not even undef)
    if o.is_a?(PUndefType) && types.empty?
      return false
    end

    return super unless o.is_a?(PVariantType)
    # If empty, all Variant types match irrespective of the types they hold (including being empty)
    return true if types.empty?
    # Since this variant is not empty, an empty Variant cannot match, because it matches nothing
    # otherwise all types in o must be assignable to this
    !o.types.empty? && o.types.all? { |vt| super(vt, guard) }
  end

  protected

  # @api private
  def _assignable?(o, guard)
    # A variant is assignable if o is assignable to any of its types
    types.any? { |option_t| option_t.assignable?(o, guard) }
  end

  # @api private
  def swap_not_undefs(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PNotUndefType) }
      not_undefs = parts[0]
      if not_undefs.size > 1
        others = parts[1]
        others <<  PNotUndefType.new(PVariantType.maybe_create(not_undefs.map { |not_undef| not_undef.type }).normalize)
        array = others
      end
    end
    array
  end

  # @api private
  def merge_enums(array)
    # Merge case sensitive enums and strings
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PEnumType) && !t.values.empty? && !t.case_insensitive? || t.is_a?(PStringType) && !t.value.nil? }
      enums = parts[0]
      if enums.size > 1
        others = parts[1]
        others <<  PEnumType.new(enums.map { |enum| enum.is_a?(PStringType) ? enum.value : enum.values }.flatten.uniq)
        array = others
      end
    end

    # Merge case insensitive enums
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PEnumType) && !t.values.empty? && t.case_insensitive? }
      enums = parts[0]
      if enums.size > 1
        others = parts[1]
        values = []
        enums.each { |enum| enum.values.each { |value| values << value.downcase }}
        values.uniq!
        others <<  PEnumType.new(values, true)
        array = others
      end
    end
    array
  end

  # @api private
  def merge_patterns(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PPatternType) }
      patterns = parts[0]
      if patterns.size > 1
        others = parts[1]
        others <<  PPatternType.new(patterns.map { |pattern| pattern.patterns }.flatten.uniq)
        array = others
      end
    end
    array
  end

  # @api private
  def merge_numbers(clazz, array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(clazz) }
      ranges = parts[0]
      array = merge_ranges(ranges) + parts[1] if ranges.size > 1
    end
    array
  end

  def merge_version_ranges(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PSemVerType) }
      ranges = parts[0]
      array = [PSemVerType.new(ranges.map(&:ranges).flatten)] + parts[1] if ranges.size > 1
    end
    array
  end

  # @api private
  def merge_ranges(ranges)
    result = []
    until ranges.empty?
      unmerged = []
      x = ranges.pop
      result << ranges.inject(x) do |memo, y|
        merged = memo.merge(y)
        if merged.nil?
          unmerged << y
        else
          memo = merged
        end
        memo
      end
      ranges = unmerged
    end
    result
  end
end

# Abstract representation of a type that can be placed in a Catalog.
# @api public
#
class PCatalogEntryType < PAnyType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType')
  end

  DEFAULT = PCatalogEntryType.new

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
  end

  protected
  # @api private
  def _assignable?(o, guard)
    o.is_a?(PCatalogEntryType)
  end
end

# Represents a (host-) class in the Puppet Language.
# @api public
#
class PClassType < PCatalogEntryType
  attr_reader :class_name

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'CatalogEntryType',
      'class_name' => {
        KEY_TYPE => POptionalType.new(PStringType::NON_EMPTY),
        KEY_VALUE => nil
      }
    )
  end

  def initialize(class_name)
    @class_name = class_name
  end

  def hash
    11 ^ @class_name.hash
  end
  def eql?(o)
    self.class == o.class && @class_name == o.class_name
  end

  DEFAULT = PClassType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PClassType)
    # Class = Class[name}, Class[name] != Class
    return true if @class_name.nil?
    # Class[name] = Class[name]
    @class_name == o.class_name
  end
end

# For backward compatibility
PHostClassType = PClassType


# Represents a Resource Type in the Puppet Language
# @api public
#
class PResourceType < PCatalogEntryType

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'CatalogEntryType',
      'type_name' => {
        KEY_TYPE => POptionalType.new(PStringType::NON_EMPTY),
        KEY_VALUE => nil
      },
      'title' => {
        KEY_TYPE => POptionalType.new(PStringType::NON_EMPTY),
        KEY_VALUE => nil
      }
    )
  end

  attr_reader :type_name, :title, :downcased_name

  def initialize(type_name, title = nil)
    @type_name = type_name.freeze
    @title = title.freeze
    @downcased_name = type_name.nil? ? nil : @type_name.downcase.freeze
  end

  def eql?(o)
    self.class == o.class && @downcased_name == o.downcased_name && @title == o.title
  end

  def hash
    @downcased_name.hash ^ @title.hash
  end

  DEFAULT = PResourceType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    o.is_a?(PResourceType) && (@downcased_name.nil? || @downcased_name == o.downcased_name && (@title.nil? || @title == o.title))
  end
end

# Represents a type that accept PUndefType instead of the type parameter
# required_type - is a short hand for Variant[T, Undef]
# @api public
#
class POptionalType < PTypeWithContainedType

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
      'type' => {
        KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
        KEY_VALUE => nil
      }
    )
  end

  def optional_type
    @type
  end

  def kind_of_callable?(optional=true, guard = nil)
      optional && !@type.nil? && @type.kind_of_callable?(optional, guard)
  end

  def instance?(o, guard = nil)
    PUndefType::DEFAULT.instance?(o, guard) || (!@type.nil? && @type.instance?(o, guard))
  end

  def normalize(guard = nil)
    n = super
    if n.type.nil?
      n
    else
      if n.type.is_a?(PNotUndefType)
        # No point in having an NotUndef in an Optional
        POptionalType.new(n.type.type).normalize
      elsif n.type.assignable?(PUndefType::DEFAULT)
        # THe type is Optional anyway, so it can be stripped of
        n.type
      else
        n
      end
    end
  end

  def new_function
    optional_type.new_function
  end

  DEFAULT = POptionalType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return true if o.is_a?(PUndefType)
    return true if @type.nil?
    if o.is_a?(POptionalType)
      @type.assignable?(o.optional_type, guard)
    else
      @type.assignable?(o, guard)
    end
  end
end

class PTypeReferenceType < PAnyType

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType', 'type_string' => PStringType::NON_EMPTY)
  end

  attr_reader :type_string

  def initialize(type_string)
    @type_string = type_string
  end

  def callable?(args)
    false
  end

  def instance?(o, guard = nil)
    false
  end

  def hash
    @type_string.hash
  end

  def eql?(o)
    super && o.type_string == @type_string
  end

  def resolve(loader)
    TypeParser.singleton.parse(@type_string, loader)
  end

  protected

  def _assignable?(o, guard)
    # A type must be assignable to itself or a lot of unit tests will break
    o == self
  end

  DEFAULT = PTypeReferenceType.new('UnresolvedReference')
end

# Describes a named alias for another Type.
# The alias is created with a name and an unresolved type expression. The type expression may
# in turn contain other aliases (including the alias that contains it) which means that an alias
# might contain self recursion. Whether or not that is the case is computed and remembered when the alias
# is resolved since guarding against self recursive constructs is relatively expensive.
#
# @api public
class PTypeAliasType < PAnyType

  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'AnyType',
       'name' => PStringType::NON_EMPTY,
       'type_expr' => PAnyType::DEFAULT,
       'resolved_type' => {
         KEY_TYPE => POptionalType.new(PTypeType::DEFAULT),
         KEY_VALUE => nil
       }
    )
  end

  attr_reader :loader, :name

  # @param name [String] The name of the type
  # @param type_expr [Model::PopsObject] The expression that describes the aliased type
  # @param resolved_type [PAnyType] the resolve type (only used for the DEFAULT initialization)
  def initialize(name, type_expr, resolved_type = nil)
    @name = name
    @type_expr = type_expr
    @resolved_type = resolved_type
    @self_recursion = false
  end

  def assignable?(o, guard = nil)
    if @self_recursion
      guard ||= RecursionGuard.new
      guard.with_this(self) { |state| state == RecursionGuard::SELF_RECURSION_IN_BOTH ? true : super(o, guard) }
    else
      super(o, guard)
    end
  end

  # Returns the resolved type. The type must have been resolved by a call prior to calls to this
  # method or an error will be raised.
  #
  # @return [PAnyType] The resolved type of this alias.
  # @raise [Puppet::Error] unless the type has been resolved prior to calling this method
  def resolved_type
    raise Puppet::Error, "Reference to unresolved type #{@name}" unless @resolved_type
    @resolved_type
  end

  def callable_args?(callable, guard)
    guarded_recursion(guard, false) { |g| resolved_type.callable_args?(callable, g) }
  end

  def check_self_recursion(originator)
    resolved_type.check_self_recursion(originator) unless originator.equal?(self)
  end

  def kind_of_callable?(optional=true, guard = nil)
    guarded_recursion(guard, false) { |g| resolved_type.kind_of_callable?(optional, g) }
  end

  def instance?(o, guard = nil)
    really_instance?(o, guard) == 1
  end

  def iterable?(guard = nil)
    guarded_recursion(guard, false) { |g| resolved_type.iterable?(g) }
  end

  def iterable_type(guard = nil)
    guarded_recursion(guard, nil) { |g| resolved_type.iterable_type(g) }
  end

  def hash
    @name.hash
  end

  # Acceptor used when checking for self recursion and that a type contains
  # something other than aliases or type references
  #
  # @api private
  class AssertOtherTypeAcceptor
    def initialize
      @other_type_detected = false
    end

    def visit(type, _)
      unless type.is_a?(PTypeAliasType) || type.is_a?(PVariantType)
        @other_type_detected = true
      end
    end

    def other_type_detected?
      @other_type_detected
    end
  end

  # Acceptor used when re-checking for self recursion after a self recursion has been detected
  #
  # @api private
  class AssertSelfRecursionStatusAcceptor
    def visit(type, _)
      type.set_self_recursion_status if type.is_a?(PTypeAliasType)
    end
  end

  def set_self_recursion_status
    return if @self_recursion || @resolved_type.is_a?(PTypeReferenceType)
    @self_recursion = true
    guard = RecursionGuard.new
    accept(NoopTypeAcceptor::INSTANCE, guard)
    @self_recursion = guard.recursive_this?(self)
    when_self_recursion_detected if @self_recursion # no difference
  end

  # Called from the TypeParser once it has found a type using the Loader. The TypeParser will
  # interpret the contained expression and the resolved type is remembered. This method also
  # checks and remembers if the resolve type contains self recursion.
  #
  # @param type_parser [TypeParser] type parser that will interpret the type expression
  # @param loader [Loader::Loader] loader to use when loading type aliases
  # @return [PTypeAliasType] the receiver of the call, i.e. `self`
  # @api private
  def resolve(loader)
    @loader = loader
    if @resolved_type.nil?
      # resolved to PTypeReferenceType::DEFAULT during resolve to avoid endless recursion
      @resolved_type = PTypeReferenceType::DEFAULT
      @self_recursion = true # assumed while it being found out below
      begin
        if @type_expr.is_a?(PTypeReferenceType)
          @resolved_type = @type_expr.resolve(loader)
        else
          @resolved_type = TypeParser.singleton.interpret(@type_expr, loader).normalize
        end

        # Find out if this type is recursive. A recursive type has performance implications
        # on several methods and this knowledge is used to avoid that for non-recursive
        # types.
        guard = RecursionGuard.new
        real_type_asserter = AssertOtherTypeAcceptor.new
        accept(real_type_asserter, guard)
        unless real_type_asserter.other_type_detected?
          raise ArgumentError, "Type alias '#{name}' cannot be resolved to a real type"
        end
        @self_recursion = guard.recursive_this?(self)
        # All aliases involved must re-check status since this alias is now resolved
        if @self_recursion
          accept(AssertSelfRecursionStatusAcceptor.new, RecursionGuard.new)
          when_self_recursion_detected
        end
      rescue
        @resolved_type = nil
        raise
      end
    else
      # An alias may appoint an Object type that isn't resolved yet. The default type
      # reference is used to prevent endless recursion and should not be resolved here.
      @resolved_type.resolve(loader) unless @resolved_type.equal?(PTypeReferenceType::DEFAULT)
    end
    self
  end

  def eql?(o)
    super && o.name == @name
  end

  def accept(visitor, guard)
    guarded_recursion(guard, nil) do |g|
      super(visitor, g)
      @resolved_type.accept(visitor, g) unless @resolved_type.nil?
    end
  end

  def self_recursion?
    @self_recursion
  end

  # Returns the expanded string the form of the alias, e.g. <alias name> = <resolved type>
  #
  # @return [String] the expanded form of this alias
  # @api public
  def to_s
    TypeFormatter.singleton.alias_expanded_string(self)
  end

  # Delegates to resolved type
  def respond_to_missing?(name, include_private)
    resolved_type.respond_to?(name, include_private)
  end

  # Delegates to resolved type
  def method_missing(name, *arguments, &block)
    super if @resolved_type.equal?(PTypeReferenceType::DEFAULT)
    resolved_type.send(name, *arguments, &block)
  end

  # @api private
  def really_instance?(o, guard = nil)
    if @self_recursion
      guard ||= RecursionGuard.new
      guard.with_that(o) do
        guard.with_this(self) { |state| state == RecursionGuard::SELF_RECURSION_IN_BOTH ? 0 : resolved_type.really_instance?(o, guard) }
      end
    else
      resolved_type.really_instance?(o, guard)
    end
  end

  # @return `nil` to prevent serialization of the type_expr used when first initializing this instance
  # @api private
  def type_expr
    nil
  end

  protected

  def _assignable?(o, guard)
    resolved_type.assignable?(o, guard)
  end

  def new_function
    resolved_type.new_function
  end

  private

  def guarded_recursion(guard, dflt)
    if @self_recursion
      guard ||= RecursionGuard.new
      guard.with_this(self) { |state| (state & RecursionGuard::SELF_RECURSION_IN_THIS) == 0 ? yield(guard) : dflt }
    else
      yield(guard)
    end
  end

  def when_self_recursion_detected
    if @resolved_type.is_a?(PVariantType)
      # Drop variants that are not real types
      resolved_types = @resolved_type.types
      real_types = resolved_types.select do |type|
        next false if type == self
        real_type_asserter = AssertOtherTypeAcceptor.new
        type.accept(real_type_asserter, RecursionGuard.new)
        real_type_asserter.other_type_detected?
      end
      if real_types.size != resolved_types.size
        if real_types.size == 1
          @resolved_type = real_types[0]
        else
          @resolved_type = PVariantType.maybe_create(real_types)
        end
        # Drop self recursion status in case it's not self recursive anymore
        guard = RecursionGuard.new
        accept(NoopTypeAcceptor::INSTANCE, guard)
        @self_recursion = guard.recursive_this?(self)
      end
    end
    @resolved_type.check_self_recursion(self) if @self_recursion
  end

  DEFAULT = PTypeAliasType.new('UnresolvedAlias', nil, PTypeReferenceType::DEFAULT)
end
end
end

require 'puppet/pops/pcore'

require_relative 'annotatable'
require_relative 'p_meta_type'
require_relative 'p_object_type'
require_relative 'annotation'
require_relative 'ruby_method'
require_relative 'p_runtime_type'
require_relative 'p_sem_ver_type'
require_relative 'p_sem_ver_range_type'
require_relative 'p_sensitive_type'
require_relative 'p_type_set_type'
require_relative 'p_timespan_type'
require_relative 'p_timestamp_type'
require_relative 'p_binary_type'
require_relative 'p_init_type'
require_relative 'p_object_type_extension'
require_relative 'p_uri_type'
require_relative 'type_set_reference'
require_relative 'implementation_registry'
require_relative 'tree_iterators'
