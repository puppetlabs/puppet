require_relative 'iterable'
require_relative 'enumeration'
require_relative 'recursion_guard'
require_relative 'type_acceptor'
require_relative 'type_asserter'
require_relative 'type_assertion_error'
require_relative 'type_formatter'
require_relative 'type_calculator'
require_relative 'type_factory'
require_relative 'type_parser'
require_relative 'class_loader'
require_relative 'type_mismatch_describer'

require 'rgen/metamodel_builder'

module Puppet::Pops
module Types
# The Types model is a model of Puppet Language types.
#
# The exact relationship between types is not visible in this model wrt. the PDataType which is an abstraction
# of Scalar, Array[Data], and Hash[Scalar, Data] nested to any depth. This means it is not possible to
# infer the type by simply looking at the inheritance hierarchy. The {TypeCalculator} should
# be used to answer questions about types. The {TypeFactory} should be used to create an instance
# of a type whenever one is needed.
#
# The implementation of the Types model contains methods that are required for the type objects to behave as
# expected when comparing them and using them as keys in hashes. (No other logic is, or should be included directly in
# the model's classes).
#
# @api public
#
# TODO: See PUP-2978 for possible performance optimization
class TypedModelObject < Object
  include Visitable
  include Adaptable
end

# Base type for all types
# @api public
#
class PAnyType < TypedModelObject
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
      # Assignable if all contained types are assignable
      o.types.all? { |vt| assignable?(vt, guard) }
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

  # Returns `true` if this instance is a callable that accepts the given _args_
  #
  # @param args [PAnyType] the arguments to test
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean] `true` if this instance is a callable that accepts the given _args_
  def callable?(args, guard = nil)
    args.is_a?(PAnyType) && kind_of_callable? && args.callable_args?(self, guard)
  end

  # Returns `true` if this instance is considered valid as arguments to the given `callable`
  # @param callable [PAnyType] the callable
  # @param guard [RecursionGuard] guard against recursion. Only used by internal calls
  # @return [Boolean] `true` if this instance is considered valid as arguments to the given `callable`
  # @api private
  def callable_args?(callable, guard)
    false
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

  # Strips the class name from all module prefixes, the leading 'P' and the ending 'Type'. I.e.
  # an instance of PVariantType will return 'Variant'
  # @return [String] the simple name of this type
  def simple_name
    n = self.class.name
    n[n.rindex('::')+3..n.size-5]
  end

  def to_alias_expanded_s
    TypeFormatter.new.alias_expanded_string(self)
  end

  def to_s
    TypeFormatter.string(self)
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

  NAME_SEGMENT_SEPARATOR = '::'.freeze

  # @api private
  def class_from_string(str)
    begin
      str.split(NAME_SEGMENT_SEPARATOR).reduce(Object) do |memo, name_segment|
        memo.const_get(name_segment)
      end
    rescue NameError
      return nil
    end
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


  # Transform size_type to min, max
  # if size_type == nil the constraint is 1,1
  # if size_type.from == nil min size = 1
  # if size_type.to == nil max size == Infinity
  #
  # @api private
  def type_to_range(size_type)
    return [1,1] if size_type.nil?
    from = size_type.from
    to = size_type.to
    [from.nil? ? 1 : from, to.nil? ? Float::INFINITY : to]
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
end

# The type of types.
# @api public
#
class PType < PTypeWithContainedType
  def instance?(o, guard = nil)
    if o.is_a?(PAnyType)
      type.nil? || type.assignable?(o, guard)
    else
      assignable?(TypeCalculator.infer(o), guard)
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

  def simple_name
    # since this the class is inconsistently named PType and not PTypeType
    'Type'
  end

  DEFAULT = PType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PType)
    return true if @type.nil? # wide enough to handle all types
    return false if o.type.nil? # wider than t
    @type.assignable?(o.type, guard)
  end
end

class PNotUndefType < PTypeWithContainedType
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
  def instance?(o, guard = nil)
    o.nil? || o == :undef
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
  def instance?(o, guard = nil)
    true
  end

  DEFAULT = PUnitType.new

  protected
  # @api private
  def _assignable?(o, guard)
    true
  end
end

# @api public
#
class PDefaultType < PAnyType
  def instance?(o, guard = nil)
    o == :default
  end

  DEFAULT = PDefaultType.new

  protected
  # @api private
  def _assignable?(o, guard)
    o.is_a?(PDefaultType)
  end
end

# A flexible data type, being assignable to its subtypes as well as PArrayType and PHashType with element type assignable to PDataType.
#
# @api public
#
class PDataType < PAnyType
  def eql?(o)
    self.class == o.class || o == PVariantType::DATA
  end

  def instance?(o, guard = nil)
    PVariantType::DATA.instance?(o, guard)
  end

  DEFAULT = PDataType.new

  protected

  # Data is assignable by other Data and by Array[Data] and Hash[Scalar, Data]
  # @api private
  def _assignable?(o, guard)
    # We cannot put the NotUndefType[Data] in the @data_variant_t since that causes an endless recursion
    case o
    when Types::PDataType
      true
    when Types::PNotUndefType
      assignable?(o.type || PUndefType::DEFAULT, guard)
    else
      PVariantType::DATA.assignable?(o, guard)
    end
  end
end

# Type that is PDataType compatible, but is not a PCollectionType.
# @api public
#
class PScalarType < PAnyType

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
  end

  DEFAULT = PScalarType.new

  protected

  # @api private
  def _assignable?(o, guard)
    o.is_a?(PScalarType)
  end
end

# A string type describing the set of strings having one of the given values
# @api public
#
class PEnumType < PScalarType
  attr_reader :values

  def initialize(values)
    @values = values.sort.freeze
  end

  # Returns Enumerator if no block is given, otherwise, calls the given
  # block with each of the strings for this enum
  def each(&block)
    r = Iterable.on(self)
    block_given? ? r.each(&block) : r
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    # An instance of an Enum is a String
    PStringType::ITERABLE_TYPE
  end

  def hash
    @values.hash
  end

  def eql?(o)
    self.class == o.class && @values == o.values
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
        # if the set of strings are all found in the set of enums
        !o.values.empty? && o.values.all? { |s| svalues.any? { |e| e == s }}
      when PEnumType
        !o.values.empty? && o.values.all? { |s| svalues.any? {|e| e == s }}
      else
        false
    end
  end
end

# @api public
#
class PNumericType < PScalarType
  def initialize(from, to = Float::INFINITY)
    from = -Float::INFINITY if from.nil? || from == :default
    to = Float::INFINITY if to.nil? || to == :default
    raise ArgumentError, "'from' must be less or equal to 'to'. Got (#{from}, #{to}" if from.is_a?(Numeric) && to.is_a?(Numeric) && from > to
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
    o.is_a?(Numeric) && o >= @from && o <= @to
  end

  def unbounded?
    @from == -Float::INFINITY && @to == Float::INFINITY
  end

  DEFAULT = PNumericType.new(-Float::INFINITY)

  protected

  # @api_private
  def _assignable?(o, guard)
    return false unless o.is_a?(self.class)
    # If o min and max are within the range of t
    @from <= o.numeric_from && @to >= o.numeric_to
  end
end

# @api public
#
class PIntegerType < PNumericType
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

  DEFAULT = PIntegerType.new(-Float::INFINITY)
end

# @api public
#
class PFloatType < PNumericType
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

  DEFAULT = PFloatType.new(-Float::INFINITY)
end

# @api public
#
class PCollectionType < PAnyType
  attr_reader :element_type, :size_type

  def initialize(element_type, size_type = nil)
    @element_type = element_type
    @size_type = size_type
    if has_empty_range? && !@element_type.is_a?(PUnitType)
      raise ArgumentError, 'An empty collection may not specify an element type'
    end
  end

  def accept(visitor, guard)
    super
    @size_type.accept(visitor, guard) unless @size_type.nil?
    @element_type.accept(visitor, guard) unless @element_type.nil?
  end

  def generalize
    if @element_type.nil?
      DEFAULT
    else
      ge_type = @element_type.generalize
      @size_type.nil? && @element_type.equal?(ge_type) ? self : self.class.new(ge_type, nil)
    end
  end

  def normalize(guard = nil)
    if @element_type.nil?
      DEFAULT
    else
      ne_type = @element_type.normalize(guard)
      @element_type.equal?(ne_type) ? self : self.class.new(ne_type, @size_type)
    end
  end

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
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
    @element_type.hash ^ @size_type.hash
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    @element_type.nil? ? PIterableType::DEFAULT : PIterableType.new(@element_type)
  end

  def eql?(o)
    self.class == o.class && @element_type == o.element_type && @size_type == o.size_type
  end


  DEFAULT_SIZE = PIntegerType.new(0)
  ZERO_SIZE = PIntegerType.new(0, 0)
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
        from, to = type_to_range(o.size_type)
        from = o.types.size - 1 + from
        to = o.types.size - 1 + to
        (@size_type || DEFAULT_SIZE).assignable?(PIntegerType.new(from, to), guard)
      when PStructType
        from = to = o.elements.size
        (@size_type || DEFAULT_SIZE).assignable?(PIntegerType.new(from, to), guard)
      else
        false
    end
  end
end

class PIterableType < PTypeWithContainedType
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
class PStringType < PScalarType
  attr_reader :size_type, :values

  def initialize(size_type, values = EMPTY_ARRAY)
    @size_type = size_type
    @values = values.sort.freeze
  end

  def accept(visitor, guard)
    super
    @size_type.accept(visitor, guard) unless @size_type.nil?
  end

  def generalize
    DEFAULT
  end

  def hash
    @size_type.hash ^ @values.hash
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    ITERABLE_TYPE
  end

  def eql?(o)
    self.class == o.class && @size_type == o.size_type && @values == o.values
  end

  def instance?(o, guard = nil)
    # true if size compliant
    if o.is_a?(String) && (@size_type.nil? || @size_type.instance?(o.size, guard))
      @values.empty? || @values.include?(o)
    else
      false
    end
  end

  DEFAULT = PStringType.new(nil)
  NON_EMPTY = PStringType.new(PIntegerType.new(1))

  # Iterates over each character of the string
  ITERABLE_TYPE = PIterableType.new(PStringType.new(PIntegerType.new(1,1)))

  protected

  # @api private
  def _assignable?(o, guard)
    if values.empty?
      # A general string is assignable by any other string or pattern restricted string
      # if the string has a size constraint it does not match since there is no reasonable way
      # to compute the min/max length a pattern will match. For enum, it is possible to test that
      # each enumerator value is within range
      case o
        when PStringType
          # true if size compliant
          (@size_type || PCollectionType::DEFAULT_SIZE).assignable?(
            o.size_type || PCollectionType::DEFAULT_SIZE, guard)

        when PPatternType
          # true if size constraint is at least 0 to +Infinity (which is the same as the default)
          @size_type.nil? || @size_type.assignable?(PCollectionType::DEFAULT_SIZE, guard)

        when PEnumType
          if o.values.empty?
            # enum represents all enums, and thus all strings, a sized constrained string can thus not
            # be assigned any enum (unless it is max size).
            @size_type.nil? || @size_type.assignable?(PCollectionType::DEFAULT_SIZE, guard)
          else
            # true if all enum values are within range
            orange = o.values.map(&:size).minmax
            srange = (@size_type || PCollectionType::DEFAULT_SIZE).range
            # If o min and max are within the range of t
            srange[0] <= orange[0] && srange[1] >= orange[1]
          end
        else
          # no other type matches string
          false
      end
    elsif o.is_a?(PStringType)
      # A specific string acts as a set of strings - must have exactly the same strings
      # In this case, size does not matter since the definition is very precise anyway
      values == o.values
    else
      # All others are false, since no other type describes the same set of specific strings
      false
    end
  end
end

# @api public
#
class PRegexpType < PScalarType
  attr_reader :pattern

  def initialize(pattern)
    @pattern = pattern
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
class PPatternType < PScalarType
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

  DEFAULT = PPatternType.new(EMPTY_ARRAY)

  protected

  # @api private
  #
  def _assignable?(o, guard)
    return true if self == o
    case o
    when PStringType, PEnumType
      if o.values.empty?
        # Strings / Enums (unknown which ones) cannot all match a pattern, but if there is no pattern it is ok
        # (There should really always be a pattern, but better safe than sorry).
        @patterns.empty?
      else
        # all strings in String/Enum type must match one of the patterns in Pattern type,
        # or Pattern represents all Patterns == all Strings
        regexps = @patterns.map { |p| p.regexp }
        regexps.empty? || o.values.all? { |v| regexps.any? {|re| re.match(v) } }
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
class PBooleanType < PScalarType

  def instance?(o, guard = nil)
    o == true || o == false
  end

  DEFAULT = PBooleanType.new

  protected

  # @api private
  #
  def _assignable?(o, guard)
    o.is_a?(PBooleanType)
  end
end

# @api public
#
# @api public
#
class PStructElement < TypedModelObject
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
    k.values[0]
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

  def <=>(o)
    self.name <=> o.name
  end

  def eql?(o)
    self == o
  end

  def ==(o)
    self.class == o.class && value_type == o.value_type && key_type == o.key_type
  end
end

# @api public
#
class PStructType < PAnyType
  include Enumerable

  def initialize(elements)
    @elements = elements.sort.freeze
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
      tc = TypeCalculator.singleton
      PIterableType.new(
        PTupleType.new([
          tc.unwrap_single_variant(PVariantType.new(@elements.map {|se| se.key_type })),
          tc.unwrap_single_variant(PVariantType.new(@elements.map {|se| se.value_type }))],
          PHashType::KEY_PAIR_TUPLE_SIZE))
    end
  end

  def eql?(o)
    self.class == o.class && @elements == o.elements
  end

  def elements
    @elements
  end

  def instance?(o, guard = nil)
    return false unless o.is_a?(Hash)
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
          if e.value_type.assignable?(o.element_type, guard)
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

  def instance?(o, guard = nil)
    return false unless o.is_a?(Array)
    # compute the tuple's min/max size, and check if that size matches
    size_t = size_type || PIntegerType.new(*size_range)

    return false unless size_t.instance?(o.size, guard)
    o.each_with_index do |element, index|
      return false unless (types[index] || types[-1]).instance?(element, guard)
    end
    true
  end

  def iterable?(guard = nil)
    true
  end

  def iterable_type(guard = nil)
    PIterableType.new(TypeCalculator.singleton.unwrap_single_variant(PVariantType.new(types)))
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

  DATA = PTupleType.new([PDataType::DEFAULT], PCollectionType::DEFAULT_SIZE)
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
        return false if o_types.empty?
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
  # Types of parameters as a Tuple with required/optional count, or an Integer with min (required), max count
  # @return [PTupleType] the tuple representing the parameter types
  attr_reader :param_types

  # Although being an abstract type reference, only Callable, or all Callables wrapped in
  # Optional or Variant are supported
  # If not set, the meaning is that block is not supported.
  # @return [PAnyType|nil] the block type
  attr_reader :block_type

  # @param param_types [PTupleType]
  # @param block_type [PAnyType|nil]
  def initialize(param_types, block_type = nil)
    @param_types = param_types
    @block_type = block_type
  end

  def accept(visitor, guard)
    super
    @param_types.accept(visitor, guard) unless @param_types.nil?
    @block_type.accept(visitor, guard) unless @block_type.nil?
  end

  def generalize
    if self == DEFAULT
      DEFAULT
    else
      params_t = @param_types.nil? ? nil : @param_types.generalize
      block_t = @block_type.nil? ? nil : @block_type.generalize
      @param_types.equal?(params_t) && @block_type.equal?(block_t) ? self : PCallableType.new(params_t, block_t)
    end
  end

  def normalize(guard = nil)
    if self == DEFAULT
      DEFAULT
    else
      params_t = @param_types.nil? ? nil : @param_types.normalize(guard)
      block_t = @block_type.nil? ? nil : @block_type.normalize(guard)
      @param_types.equal?(params_t) && @block_type.equal?(block_t) ? self : PCallableType.new(params_t, block_t)
    end
  end

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
  end

  # @api private
  def callable_args?(required_callable_t, guard)
    # If the required callable is euqal or more specific than self, self is acceptable arguments
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
    @param_types.hash ^ @block_type.hash
  end

  def eql?(o)
    self.class == o.class && @param_types == o.param_types && @block_type == o.block_type
  end

  DEFAULT = PCallableType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PCallableType)
    # nil param_types means, any other Callable is assignable
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

  # @api private
  def callable_args?(callable, guard = nil)
    param_t = callable.param_types
    block_t = callable.block_type
    # does not support calling with a block, but have to check that callable is ok with missing block
    (param_t.nil? || param_t.assignable?(self, guard)) && (block_t.nil? || block_t.assignable(PUndefType::DEFAULT, guard))
  end

  def generalize
    if self == DATA
      self
    else
      super
    end
  end

  def normalize(guard = nil)
    if self == DATA
      self
    else
      super
    end
  end

  def instance?(o, guard = nil)
    return false unless o.is_a?(Array)
    element_t = element_type
    return false unless element_t.nil? || o.all? {|element| element_t.instance?(element, guard) }
    size_t = size_type
    size_t.nil? || size_t.instance?(o.size, guard)
  end

  DATA = PArrayType.new(PDataType::DEFAULT, DEFAULT_SIZE)
  DEFAULT = PArrayType.new(nil)
  EMPTY = PArrayType.new(PUnitType::DEFAULT, ZERO_SIZE)

  protected

  # Array is assignable if o is an Array and o's element type is assignable, or if o is a Tuple
  # @api private
  def _assignable?(o, guard)
    s_entry = element_type
    if o.is_a?(PTupleType)
      # If s_entry is nil, this Array type has no opinion on element types. Therefore any
      # tuple can be assigned.
      return true if s_entry.nil?

      return false unless o.types.all? {|o_element_t| s_entry.assignable?(o_element_t, guard) }
      o_regular = o.types[0..-2]
      o_ranged = o.types[-1]
      o_from, o_to = type_to_range(o.size_type)
      o_required = o_regular.size + o_from

      # array type may be size constrained
      size_s = size_type || DEFAULT_SIZE
      min, max = size_s.range
      # Tuple with fewer min entries can not be assigned
      return false if o_required < min
      # Tuple with more optionally available entries can not be assigned
      return false if o_regular.size + o_to > max
      # each tuple type must be assignable to the element type
      o_required.times do |index|
        o_entry = tuple_entry_at(o, o_to, index)
        return false unless s_entry.assignable?(o_entry, guard)
      end
      # ... and so must the last, possibly optional (ranged) type
      s_entry.assignable?(o_ranged)
    elsif o.is_a?(PArrayType)
      super && (s_entry.nil? || s_entry.assignable?(o.element_type, guard))
    else
      false
    end
  end
end

# @api public
#
class PHashType < PCollectionType
  attr_accessor :key_type

  def initialize(key_type, value_type, size_type = nil)
    super(value_type, size_type)
    @key_type = key_type
    if has_empty_range? && !@key_type.is_a?(PUnitType)
      raise ArgumentError, 'An empty hash may not specify a key type'
    end
  end

  def accept(visitor, guard)
    super
    @key_type.accept(visitor, guard) unless @key_type.nil?
  end

  def generalize
    if self == DEFAULT || self == DATA || self == EMPTY
      self
    else
      key_t = @key_type
      key_t = key_t.generalize unless key_t.nil?
      value_t = @element_type
      value_t = value_t.generalize unless value_t.nil?
      @size_type.nil? && @key_type.equal?(key_t) && @element_type.equal?(value_t) ? self : PHashType.new(key_t, value_t, nil)
    end
  end

  def normalize(guard = nil)
    if self == DEFAULT || self == DATA || self == EMPTY
      self
    else
      key_t = @key_type
      key_t = key_t.normalize(guard) unless key_t.nil?
      value_t = @element_type
      value_t = value_t.normalize(guard) unless value_t.nil?
      @size_type.nil? && @key_type.equal?(key_t) && @element_type.equal?(value_t) ? self : PHashType.new(key_t, value_t, nil)
    end
  end

  def hash
    super ^ @key_type.hash
  end

  def instance?(o, guard = nil)
    return false unless o.is_a?(Hash)
    key_t = key_type
    element_t = element_type
    if (key_t.nil? || o.keys.all? {|key| key_t.instance?(key, guard) }) &&
        (element_t.nil? || o.values.all? {|value| element_t.instance?(value, guard) })
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
      PIterableType.new(PTupleType.new([@key_type, @element_type], KEY_PAIR_TUPLE_SIZE))
    end
  end

  def eql?(o)
    super && @key_type == o.key_type
  end

  def is_the_empty_hash?
    self == EMPTY
  end

  DEFAULT = PHashType.new(nil, nil)
  KEY_PAIR_TUPLE_SIZE = PIntegerType.new(2,2)
  DEFAULT_KEY_PAIR_TUPLE = PTupleType.new([PUnitType::DEFAULT, PUnitType::DEFAULT], KEY_PAIR_TUPLE_SIZE)
  DATA = PHashType.new(PScalarType::DEFAULT, PDataType::DEFAULT, DEFAULT_SIZE)
  EMPTY = PHashType.new(PUnitType::DEFAULT, PUnitType::DEFAULT, PIntegerType.new(0, 0))

  protected

  # Hash is assignable if o is a Hash and o's key and element types are assignable
  # @api private
  def _assignable?(o, guard)
    case o
      when PHashType
        size_s = size_type
        return true if (size_s.nil? || size_s.from == 0) && o.is_the_empty_hash?
        return false unless (key_type.nil? || key_type.assignable?(o.key_type, guard)) && (element_type.nil? || element_type.assignable?(o.element_type, guard))
        super
      when PStructType
        # hash must accept String as key type
        # hash must accept all value types
        # hash must accept the size of the struct
        o_elements = o.elements
        (size_type || DEFAULT_SIZE).instance?(o_elements.size, guard) &&
            o_elements.all? {|e| (key_type.nil? || key_type.instance?(e.name, guard)) && (element_type.nil? || element_type.assignable?(e.value_type, guard)) }
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

  attr_reader :types

  # @param types [Array[PAnyType]] the variants
  def initialize(types)
    @types = types.uniq.freeze
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
    if self == DEFAULT || self == DATA
      self
    else
      alter_type_array(@types, :generalize) { |altered| PVariantType.new(altered) }
    end
  end

  def normalize(guard = nil)
    if self == DEFAULT || self == DATA || @types.empty?
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
      elsif types.any? { |t| t.is_a?(PUndefType) }
        # Undef entry present. Use an OptionalType with a normalized Variant of all types that are not Undef
        POptionalType.new(PVariantType.new(types.reject { |ot| ot.is_a?(PUndefType) }).normalize(guard)).normalize(guard)
      else
        # Merge all variants into this one
        types = types.map do |t|
          if t.is_a?(PVariantType)
            modified = true
            t.types
          else
            t
          end
        end
        types.flatten! if modified
        size_before_merge = types.size

        types = swap_not_undefs(types)
        types = swap_optionals(types)
        types = merge_enums(types)
        types = merge_patterns(types)
        types = merge_int_ranges(types)
        types = merge_float_ranges(types)

        if types.size == 1
          types[0]
        else
          modified || types.size != size_before_merge ? PVariantType.new(types) : self
        end
      end
    end
  end

  def hash
    @types.hash
  end

  def instance?(o, guard = nil)
    # instance of variant if o is instance? of any of variant's types
    @types.any? { |type| type.instance?(o, guard) }
  end

  def really_instance?(o, guard = nil)
    @types.inject(-1) do |memo, type|
      ri = type.really_instance?(o, guard)
      memo = ri if ri > memo
      memo
    end
  end

  def kind_of_callable?(optional = true, guard = nil)
    @types.all? { |type| type.kind_of_callable?(optional, guard) }
  end

  def resolved?
    @types.all? { |type| type.resolved? }
  end

  def eql?(o)
    o = DATA if o.is_a?(PDataType)
    self.class == o.class && @types.size == o.types.size && (@types - o.types).empty?
  end

  # Variant compatible with the Data type.
  DATA = PVariantType.new([PHashType::DATA, PArrayType::DATA, PScalarType::DEFAULT, PUndefType::DEFAULT, PTupleType::DATA])

  DEFAULT = PVariantType.new(EMPTY_ARRAY)

  protected

  # @api private
  def _assignable?(o, guard)
    # Data is a specific variant
    o = DATA if o.is_a?(PDataType)
    if o.is_a?(PVariantType)
      # A variant is assignable if all of its options are assignable to one of this type's options
      return true if self == o
      o.types.all? do |other|
        # if the other is a Variant, all of its options, but be assignable to one of this type's options
        other = other.is_a?(PDataType) ? DATA : other
        if other.is_a?(PVariantType)
          assignable?(other, guard)
        else
          types.any? {|option_t| option_t.assignable?(other, guard) }
        end
      end
    else
      # A variant is assignable if o is assignable to any of its types
      types.any? { |option_t| option_t.assignable?(o, guard) }
    end
  end

  # @api private
  def swap_optionals(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(POptionalType) }
      optionals = parts[0]
      if optionals.size > 1
        others = parts[1]
        others <<  POptionalType.new(PVariantType.new(optionals.map { |optional| optional.type }).normalize)
        array = others
      end
    end
    array
  end

  # @api private
  def swap_not_undefs(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PNotUndefType) }
      not_undefs = parts[0]
      if not_undefs.size > 1
        others = parts[1]
        others <<  PNotUndefType.new(PVariantType.new(not_undefs.map { |not_undef| not_undef.type }).normalize)
        array = others
      end
    end
    array
  end

  # @api private
  def merge_enums(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PEnumType) || t.is_a?(PStringType) && !t.values.empty? }
      enums = parts[0]
      if enums.size > 1
        others = parts[1]
        others <<  PEnumType.new(enums.map { |enum| enum.values }.flatten.uniq)
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
  def merge_int_ranges(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PIntegerType) }
      ranges = parts[0]
      array = merge_ranges(ranges) + parts[1] if ranges.size > 1
    end
    array
  end

  def merge_float_ranges(array)
    if array.size > 1
      parts = array.partition {|t| t.is_a?(PFloatType) }
      ranges = parts[0]
      array = merge_ranges(ranges) + parts[1] if ranges.size > 1
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

# @api public
#
class PRuntimeType < PAnyType
  attr_reader :runtime, :runtime_type_name

  def initialize(runtime, runtime_type_name = nil)
    @runtime = runtime
    @runtime_type_name = runtime_type_name
  end

  def hash
    @runtime.hash ^ @runtime_type_name.hash
  end

  def eql?(o)
    self.class == o.class && @runtime == o.runtime && @runtime_type_name == o.runtime_type_name
  end

  def instance?(o, guard = nil)
    assignable?(TypeCalculator.infer(o), guard)
  end

  def iterable?(guard = nil)
    c = class_from_string(@runtime_type_name)
    c.nil? ? false : c < Iterable
  end

  def iterable_type(guard = nil)
    iterable?(guard) ? PIterableType.new(self) : nil
  end

  DEFAULT = PRuntimeType.new(nil)

  protected

  # Assignable if o's has the same runtime and the runtime name resolves to
  # a class that is the same or subclass of t1's resolved runtime type name
  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PRuntimeType)
    return false unless @runtime == o.runtime
    return true if @runtime_type_name.nil?   # t1 is wider
    return false if o.runtime_type_name.nil?  # t1 not nil, so o can not be wider

    # NOTE: This only supports Ruby, must change when/if the set of runtimes is expanded
    c1 = class_from_string(@runtime_type_name)
    c2 = class_from_string(o.runtime_type_name)
    return false unless c1.is_a?(Module) && c2.is_a?(Module)
    !!(c2 <= c1)
  end
end

# Abstract representation of a type that can be placed in a Catalog.
# @api public
#
class PCatalogEntryType < PAnyType

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
class PHostClassType < PCatalogEntryType
  attr_reader :class_name

  def initialize(class_name)
    @class_name = class_name
  end

  def hash
    11 ^ @class_name.hash
  end
  def eql?(o)
    self.class == o.class && @class_name == o.class_name
  end

  DEFAULT = PHostClassType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PHostClassType)
    # Class = Class[name}, Class[name] != Class
    return true if @class_name.nil?
    # Class[name] = Class[name]
    @class_name == o.class_name
  end
end

# Represents a Resource Type in the Puppet Language
# @api public
#
class PResourceType < PCatalogEntryType
  attr_reader :type_name, :title

  def initialize(type_name, title = nil)
    @type_name = type_name
    @title = title
  end

  def hash
    @type_name.hash ^ @title.hash
  end

  def eql?(o)
    self.class == o.class && @type_name == o.type_name && @title == o.title
  end

  DEFAULT = PResourceType.new(nil)

  protected

  # @api private
  def _assignable?(o, guard)
    return false unless o.is_a?(PResourceType)
    return true if @type_name.nil?
    return false if @type_name != o.type_name
    return true if @title.nil?
    @title == o.title
  end
end

# Represents a type that accept PUndefType instead of the type parameter
# required_type - is a short hand for Variant[T, Undef]
# @api public
#
class POptionalType < PTypeWithContainedType
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
  attr_reader :name, :parameters

  def initialize(name, parameters = nil)
    @name = name
    @parameters = parameters.nil? ? EMPTY_ARRAY : parameters
  end

  def callable?(args)
    false
  end

  def instance?(o, guard = nil)
    false
  end

  def hash
    @name.hash ^ @parameters.hash
  end

  def eql?(o)
    super && o.name == @name && o.parameters == @parameters
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
class PTypeAliasType < PAnyType
  attr_reader :name

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
      return true if guard.add_this(self) == RecursionGuard::SELF_RECURSION_IN_BOTH
    end
    super(o, guard)
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
      unless type.is_a?(PTypeAliasType) || type.is_a?(PVariantType) || type.is_a?(PTypeReferenceType)
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
  def resolve(type_parser, loader)
    if @resolved_type.nil?
      # resolved to PTypeReferenceType::DEFAULT during resolve to avoid endless recursion
      @resolved_type = PTypeReferenceType::DEFAULT
      @self_recursion = true # assumed while it being found out below
      begin
        @resolved_type = type_parser.interpret(@type_expr, loader).normalize

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
    end
    self
  end

  def eql?(o)
    super && o.name == @name
  end

  def accept(visitor, guard)
    guarded_recursion(guard, nil) do |g|
      super
      resolved_type.accept(visitor, g)
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
    resolved_type.send(name, *arguments, &block)
  end

  # @api private
  def really_instance?(o, guard = nil)
    if @self_recursion
      guard ||= RecursionGuard.new
      guard.add_that(o)
      return 0 if guard.add_this(self) == RecursionGuard::SELF_RECURSION_IN_BOTH
    end
    resolved_type.really_instance?(o, guard)
  end

  protected

  def _assignable?(o, guard)
    resolved_type.assignable?(o, guard)
  end

  private

  def guarded_recursion(guard, dflt)
    if @self_recursion
      guard ||= RecursionGuard.new
      (guard.add_this(self) & RecursionGuard::SELF_RECURSION_IN_THIS) == 0 ? yield(guard) : dflt
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
        accept(real_type_asserter, RecursionGuard.new)
        real_type_asserter.other_type_detected?
      end
      if real_types.size != resolved_types.size
        if real_types.size == 1
          @resolved_type = real_types[0]
        else
          @resolved_type = PVariantType.new(real_types)
        end
        # Drop self recursion status in case it's not self recursive anymore
        guard = RecursionGuard.new
        accept(NoopTypeAcceptor::INSTANCE, guard)
        @self_recursion = guard.recursive_this?(self)
      end
    end
  end

  DEFAULT = PTypeAliasType.new('UnresolvedAlias', nil, PTypeReferenceType::DEFAULT)
end
end
end
