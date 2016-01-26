require_relative 'iterable'
require_relative 'enumeration'
require_relative 'type_asserter'
require_relative 'type_assertion_error'
require_relative 'type_calculator'
require_relative 'type_factory'
require_relative 'type_parser'
require_relative 'class_loader'
require_relative 'type_mismatch_describer'

require 'rgen/metamodel_builder'

# The Types model is a model of Puppet Language types.
#
# The exact relationship between types is not visible in this model wrt. the PDataType which is an abstraction
# of Scalar, Array[Data], and Hash[Scalar, Data] nested to any depth. This means it is not possible to
# infer the type by simply looking at the inheritance hierarchy. The {Puppet::Pops::Types::TypeCalculator} should
# be used to answer questions about types. The {Puppet::Pops::Types::TypeFactory} should be used to create an instance
# of a type whenever one is needed.
#
# The implementation of the Types model contains methods that are required for the type objects to behave as
# expected when comparing them and using them as keys in hashes. (No other logic is, or should be included directly in
# the model's classes).
#
# @api public
#
module Puppet::Pops
  # TODO: See PUP-2978 for possible performance optimization
  module Types
    class TypedModelObject < Object
      include Puppet::Pops::Visitable
      include Puppet::Pops::Adaptable
    end

    # Base type for all types
    # @api public
    #
    class PAnyType < TypedModelObject
      # Checks if _o_ is a type that is assignable to this type.
      # If _o_ is a `Class` then it is first converted to a type.
      # If _o_ is a Variant, then it is considered assignable when all its types are assignable
      # @return [Boolean] `true` when _o_ is assignable to this type
      # @api public
      def assignable?(o)
        case o
          when Class
          # Safe to call _assignable directly since a Class never is a Unit or Variant
          _assignable?(Puppet::Pops::Types::TypeCalculator.singleton.type(o))
        when PUnitType
          true
        when PVariantType
          # Assignable if all contained types are assignable
          o.types.all? { |vt| assignable?(vt) }
        when PNotUndefType
          if !(o.type.nil? || o.type.assignable?(PUndefType::DEFAULT))
            assignable?(o.type)
          else
            _assignable?(o)
          end
        else
          _assignable?(o)
        end
      end

      # Returns `true` if this instance is a callable that accepts the given _args_
      #
      # @return [Boolean]
      def callable?(args)
        args.is_a?(PAnyType) && kind_of_callable? && args.callable_args?(self)
      end

      # Returns `true` if this instance is considered valid as arguments to _callable_
      # @return [Boolean]
      # @api private
      def callable_args?(callable)
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

      # Responds `true` for all callables, variants of callables and unless _optional_ is
      # false, all optional callables.
      # @return [Boolean] `true`if this type is considered callable
      # @api private
      def kind_of_callable?(optional=true)
        false
      end

      # Returns `true` if an instance of this type is iterable, `false` otherwise
      # The method #iterable_type must produce a `PIterableType` instance when this
      # method returns `true`
      #
      # @return [Boolean] flag to indicate if instances of  this type is iterable.
      def iterable?
        false
      end

      # Returns the `PIterableType` that this type should be assignable to to, or `nil` if no such type exists.
      # A type that returns a `PIterableType` must respond `true` to `#iterable?`.
      #
      # Any Collection[T] is assignable to an Iterable[T]
      # A String is assignable to an Iterable[String] iterating over the strings characters
      # An Integer is assignable to an Iterable[Integer] iterating over the 'times' enumerator
      # A Type[T] is assignabel to an Iterable[Type[T]] if T is an Integer or Enum
      #
      # @return [PIterableType,nil] The iterable type that this type is assignable to or `nil`
      # @api private
      def iterable_type
        nil
      end

      def hash
        self.class.hash
      end

      # Returns true if the given argument _o_ is an instance of this type
      # @return [Boolean]
      def instance?(o)
        true
      end

      def ==(o)
        self.class == o.class
      end

      alias eql? ==

      # Strips the class name from all module prefixes, the leading 'P' and the ending 'Type'. I.e.
      # an instance of Puppet::Pops::Types::PVariantType will return 'Variant'
      # @return [String] the simple name of this type
      def simple_name
        n = self.class.name
        n[n.rindex('::')+3..n.size-5]
      end

      def to_s
        Puppet::Pops::Types::TypeCalculator.string(self)
      end

      # The default instance of this type. Each type in the type system has this constant
      # declared.
      #
      DEFAULT = PAnyType.new

      protected

      # @api private
      def _assignable?(o)
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
      def tuple_entry_at(tuple_t, from, to, index)
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
    end

    # The type of types.
    # @api public
    #
    class PType < PAnyType
      attr_reader :type

      def initialize(type)
        @type = type
      end

      def instance?(o)
        if o.is_a?(PAnyType)
          type.nil? || type.assignable?(o)
        else
          assignable?(TypeCalculator.infer(o))
        end
      end

      def generalize
        @type.nil? ? DEFAULT : PType.new(type.generalize)
      end

      def hash
        31 * @type.hash
      end

      def iterable?
        case @type
        when PEnumType
          true
        when PIntegerType
          @type.enumerable?
        else
          false
        end
      end

      def iterable_type
        # The types PIntegerType and PEnumType are Iterable
        case @type
        when PEnumType
          @type.each
        when PIntegerType
          @type.enumerable? ? @type.each : nil
        else
          nil
        end
      end

      def ==(o)
        self.class == o.class && @type == o.type
      end

      def simple_name
        # since this the class is inconsistently named PType and not PTypeType
        'Type'
      end

      DEFAULT = PType.new(nil)

      protected

      # @api private
      def _assignable?(o)
        return false unless o.is_a?(PType)
        return true if @type.nil? # wide enough to handle all types
        return false if o.type.nil? # wider than t
        @type.assignable?(o.type)
      end
    end

    class PNotUndefType < PAnyType
      attr_reader :type

      def initialize(type = nil)
        @type = type.class == PAnyType ? nil : type
      end

      def instance?(o)
        !(o.nil? || o == :undef) && (@type.nil? || @type.instance?(o))
      end

      def generalize
        @type.nil? ? DEFAULT : PNotUndefType.new(type.generalize)
      end

      def hash
        31 * @type.hash
      end

      def ==(o)
        self.class == o.class && @type == o.type
      end

      DEFAULT = PNotUndefType.new

      protected

      # @api private
      def _assignable?(o)
        o.is_a?(PAnyType) && !o.assignable?(PUndefType::DEFAULT) && (@type.nil? || @type.assignable?(o))
      end
    end

    # @api public
    #
    class PUndefType < PAnyType
      def instance?(o)
        o.nil? || o == :undef
      end

      # @api private
      def callable_args?(callable_t)
        # if callable_t is Optional (or indeed PUndefType), this means that 'missing callable' is accepted
        callable_t.assignable?(DEFAULT)
      end

      DEFAULT = PUndefType.new

      protected
      # @api private
      def _assignable?(o)
        o.is_a?(PUndefType)
      end
    end

    # A type private to the type system that describes "ignored type" - i.e. "I am what you are"
    # @api private
    #
    class PUnitType < PAnyType
      def instance?(o)
        true
      end

      DEFAULT = PUnitType.new

      protected
      # @api private
      def _assignable?(o)
        true
      end
    end

    # @api public
    #
    class PDefaultType < PAnyType
      def instance?(o)
        o == :default
      end

      DEFAULT = PDefaultType.new

      protected
      # @api private
      def _assignable?(o)
        o.is_a?(PDefaultType)
      end
    end

    # A flexible data type, being assignable to its subtypes as well as PArrayType and PHashType with element type assignable to PDataType.
    #
    # @api public
    #
    class PDataType < PAnyType
      def ==(o)
        self.class == o.class || o.class == PVariantType && o == PVariantType::DATA
      end

      def instance?(o)
        PVariantType::DATA.instance?(o)
      end

      DEFAULT = PDataType.new

      protected

      # Data is assignable by other Data and by Array[Data] and Hash[Scalar, Data]
      # @api private
      def _assignable?(o)
        # We cannot put the NotUndefType[Data] in the @data_variant_t since that causes an endless recursion
        case o
        when Types::PDataType
          true
        when Types::PNotUndefType
          assignable?(o.type || PUndefType::DEFAULT)
        else
          PVariantType::DATA.assignable?(o)
        end
      end
    end

    # Type that is PDataType compatible, but is not a PCollectionType.
    # @api public
    #
    class PScalarType < PAnyType

      def instance?(o)
        assignable?(TypeCalculator.infer(o))
      end

      DEFAULT = PScalarType.new

      protected

      # @api private
      def _assignable?(o)
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

      def iterable?
        true
      end

      def iterable_type
        PIterableType.new(PStringType::DEFAULT)
      end

      def hash
        @values.hash
      end

      def ==(o)
        self.class == o.class && @values == o.values
      end

      DEFAULT = PEnumType.new([])

      protected

      # @api private
      def _assignable?(o)
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
        @from.hash * 31 + @to.hash
      end

      def ==(o)
        self.class == o.class && @from == o.numeric_from && @to == o.numeric_to
      end

      def instance?(o)
        o.is_a?(Numeric) && o >= @from && o <= @to
      end

      def unbounded?
        @from == -Float::INFINITY && @to == Float::INFINITY
      end

      DEFAULT = PNumericType.new(-Float::INFINITY)

      protected

      # @api_private
      def _assignable?(o)
        return false unless o.is_a?(self.class)
        # If o min and max are within the range of t
        @from <= o.numeric_from && @to >= o.numeric_to
      end
    end

    # @api public
    #
    class PIntegerType < PNumericType
      # Answers the question, "is this instance of PIntegerType enumerable?" (as opposed to if instances described by
      # this type is enumerable). Will respond `true` for any range that is bounded at both ends.
      #
      # @return [Boolean] `true` if the type is enumerable.
      def enumerable?
        @from != -Float::INFINITY && @to != Float::INFINITY
      end

      def generalize
        DEFAULT
      end

      def instance?(o)
        o.is_a?(Integer) && o >= numeric_from && o <= numeric_to
      end

      def iterable?
        true
      end

      def iterable_type
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

      def instance?(o)
        o.is_a?(Float) && o >= numeric_from && o <= numeric_to
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
      end

      def generalize
        @element_type.nil? ? DEFAULT : PCollectionType.new(element_type.generalize, nil)
      end

      def instance?(o)
        assignable?(TypeCalculator.infer(o))
      end

      # Returns an array with from (min) size to (max) size
      def size_range
        (@size_type || DEFAULT_SIZE).range
      end

      def hash
        @element_type.hash * 31 + @size_type.hash
      end

      def iterable?
        true
      end

      def iterable_type
        PIterableType.new(element_type)
      end

      def ==(o)
        self.class == o.class && @element_type == o.element_type && @size_type == o.size_type
      end


      DEFAULT_SIZE = PIntegerType.new(0)
      ZERO_SIZE = PIntegerType.new(0, 0)
      DEFAULT = PCollectionType.new(nil)

      protected

      # @api private
      #
      def _assignable?(o)
        case o
          when PCollectionType
            (@size_type || DEFAULT_SIZE).assignable?(o.size_type || DEFAULT_SIZE)
          when PTupleType
            # compute the tuple's min/max size, and check if that size matches
            from, to = type_to_range(o.size_type)
            from = o.types.size - 1 + from
            to = o.types.size - 1 + to
            (@size_type || DEFAULT_SIZE).assignable?(PIntegerType.new(from, to))
          when PStructType
            from = to = o.elements.size
            (@size_type || DEFAULT_SIZE).assignable?(PIntegerType.new(from, to))
          else
            false
        end
      end
    end

    class PIterableType < PAnyType
      attr_reader :element_type

      def initialize(type)
        @element_type = type
      end

      def instance?(o)
        if @element_type.nil? || @element_type.assignable?(PAnyType::DEFAULT)
          # Any element_type will do
          case o
          when Iterable, String, Hash, Enumerable, Enumerator, Range, PEnumType
            true
          when Integer
            o > 0
          when PIntegerType
            o.enumerable?
          else
            false
          end
        else
          assignable?(TypeCalculator.infer(o))
        end
      end

      def generalize
        @element_type.nil? ? DEFAULT : PIterableType.new(@element_type.generalize)
      end

      def hash
        67 * @element_type.hash
      end

      def iterable?
        true
      end

      def iterable_type
        self
      end

      def ==(o)
        self.class == o.class && @element_type == o.element_type
      end

      DEFAULT = PIterableType.new(nil)

      protected

      # @api private
      def _assignable?(o)
        if @element_type.nil? || @element_type.assignable?(PAnyType::DEFAULT)
          # Don't request the iterable_type since it might be expensive to compute the
          # type of its elements
          o.iterable?
        else
          o = o.iterable_type
          o.nil? || o.element_type.nil? ? false : @element_type.assignable?(o.element_type)
        end
      end
    end

    # @api public
    #
    class PIteratorType < PAnyType
      attr_reader :element_type

      def initialize(type)
        @element_type = type
      end

      def instance?(o)
        o.is_a?(Iterable) && (@element_type.nil? || @element_type.assignable?(o.element_type))
      end

      def generalize
        @element_type.nil? ? DEFAULT : PIteratorType.new(@element_type.generalize)
      end

      def hash
        71 * @element_type.hash
      end

      def iterable?
        true
      end

      def iterable_type
        element_type.nil? ? PIteratbleType::DEFAULT : PIterableType.new(@element_type)
      end

      def ==(o)
        self.class == o.class && @element_type == o.element_type
      end

      DEFAULT = PIteratorType.new(nil)

      protected

      # @api private
      def _assignable?(o)
        o.is_a?(PIteratorType) && (@element_type.nil? || @element_type.assignable?(o.element_type))
      end
    end

    # @api public
    #
    class PStringType < PScalarType
      attr_reader :size_type, :values

      def generalize
        DEFAULT
      end

      def initialize(size_type, values = [])
        @size_type = size_type
        @values = values.sort.freeze
      end

      def hash
        @size_type.hash * 31 + @values.hash
      end

      def iterable?
        true
      end

      def iterable_type
        PIterableType.new(PStringType::DEFAULT)
      end

      def ==(o)
        self.class == o.class && @size_type == o.size_type && @values == o.values
      end

      def instance?(o)
        # true if size compliant
        if o.is_a?(String) && (@size_type.nil? || @size_type.instance?(o.size))
          @values.empty? || @values.include?(o)
        else
          false
        end
      end

      DEFAULT = PStringType.new(nil)
      NON_EMPTY = PStringType.new(PIntegerType.new(1))

      protected

      # @api private
      def _assignable?(o)
        if values.empty?
          # A general string is assignable by any other string or pattern restricted string
          # if the string has a size constraint it does not match since there is no reasonable way
          # to compute the min/max length a pattern will match. For enum, it is possible to test that
          # each enumerator value is within range
          case o
            when PStringType
              # true if size compliant
              (@size_type || PCollectionType::DEFAULT_SIZE).assignable?(o.size_type || PCollectionType::DEFAULT_SIZE)

            when PPatternType
              # true if size constraint is at least 0 to +Infinity (which is the same as the default)
              @size_type.nil? || @size_type.assignable?(PCollectionType::DEFAULT_SIZE)

            when PEnumType
              if o.values.empty?
                # enum represents all enums, and thus all strings, a sized constrained string can thus not
                # be assigned any enum (unless it is max size).
                @size_type.nil? || @size_type.assignable?(PCollectionType::DEFAULT_SIZE)
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

      def ==(o)
        self.class == o.class && @pattern == o.pattern
      end

      DEFAULT = PRegexpType.new(nil)

      protected

      # @api private
      #
      def _assignable?(o)
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

      def hash
        @patterns.hash
      end

      def ==(o)
        self.class == o.class && (@patterns | o.patterns).size == @patterns.size
      end

      DEFAULT = PPatternType.new([])

      protected

      # @api private
      #
      def _assignable?(o)
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

      def instance?(o)
        o == true || o == false
      end

      DEFAULT = PBooleanType.new

      protected

      # @api private
      #
      def _assignable?(o)
        o.is_a?(PBooleanType)
      end
    end

    # @api public
    #
    # @api public
    #
    class PStructElement < TypedModelObject
      attr_accessor :key_type, :value_type

      def hash
        value_type.hash * 31 + key_type.hash
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
        PStructElement.new(@key_type, @value_type.generalize)
      end

      def <=>(o)
        self.name <=> o.name
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

      def each
        if block_given?
          elements.each { |elem| yield elem }
        else
          elements.to_enum
        end
      end

      def generalize
        @elements.empty? ? DEFAULT : PStructType.new(@elements.map { |se| se.generalize })
      end

      def hashed_elements
        @hashed ||= @elements.reduce({}) {|memo, e| memo[e.name] = e; memo }
      end

      def hash
        @elements.hash
      end

      def iterable?
        true
      end

      def iterable_type
        if self == DEFAULT
          PIterableType.new(PTupleType.new([PAnyType::DEFAULT], PHashType::TUPLE_SIZE))
        else
          tc = TypeCalculator.singleton
          key_type = tc.infer_and_reduce_type(@elements.map {|se| se.key_type })
          value_type = tc.infer_and_reduce_type(@elements.map {|se| se.value_type })
          PIterableType.new(PTupleType.new([key_type, value_type], PHashType::TUPLE_SIZE))
        end
      end

      def ==(o)
        self.class == o.class && @elements == o.elements
      end

      def elements
        @elements
      end

      def instance?(o)
        return false unless o.is_a?(Hash)
        matched = 0
        @elements.all? do |e|
          key = e.name
          v = o[key]
          if v.nil? && !o.include?(key)
            # Entry is missing. Only OK when key is optional
            e.key_type.assignable?(PUndefType::DEFAULT)
          else
            matched += 1
            e.value_type.instance?(v)
          end
        end && matched == o.size
      end

      DEFAULT = PStructType.new([])

      protected

      # @api private
      def _assignable?(o)
        if o.is_a?(Types::PStructType)
          h2 = o.hashed_elements
          matched = 0
          elements.all? do |e1|
            e2 = h2[e1.name]
            if e2.nil?
              e1.key_type.assignable?(PUndefType::DEFAULT)
            else
              matched += 1
              e1.key_type.assignable?(e2.key_type) && e1.value_type.assignable?(e2.value_type)
            end
          end && matched == h2.size
        elsif o.is_a?(Types::PHashType)
          required = 0
          required_elements_assignable = elements.all? do |e|
            if e.key_type.assignable?(PUndefType::DEFAULT)
              true
            else
              required += 1
              e.value_type.assignable?(o.element_type)
            end
          end
          if required_elements_assignable
            size_o = o.size_type || collection_default_size_t
            PIntegerType.new(required, elements.size).assignable?(size_o)
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

      # @api private
      def callable_args?(callable_t)
        unless size_type.nil?
          raise ArgumentError, 'Callable tuple may not have a size constraint when used as args'
        end

        params_tuple = callable_t.param_types
        param_block_t = callable_t.block_type
        arg_types = @types
        arg_block_t = arg_types.last
        if arg_block_t.kind_of_callable?
          # Can't pass a block to a callable that doesn't accept one
          return false if param_block_t.nil?

          # Check that the block is of the right tyṕe
          return false unless param_block_t.assignable?(arg_block_t)

          # Check other arguments
          arg_count = arg_types.size - 1
          params_size_t = params_tuple.size_type || PIntegerType.new(*params_tuple.size_range)
          return false unless params_size_t.assignable?(PIntegerType.new(arg_count, arg_count))

          ctypes = params_tuple.types
          arg_count.times do |index|
            return false unless (ctypes[index] || ctypes[-1]).assignable?(arg_types[index])
          end
          return true
        end

        # Check that tuple is assignable and that the block (if declared) is optional
        params_tuple.assignable?(self) && (param_block_t.nil? || param_block_t.assignable?(PUndefType::DEFAULT))
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
        self == DEFAULT ? self : PTupleType.new(@types.map {|t| t.generalize })
      end

      def instance?(o)
        return false unless o.is_a?(Array)
        # compute the tuple's min/max size, and check if that size matches
        size_t = size_type || PIntegerType.new(*size_range)

        return false unless size_t.instance?(o.size)
        o.each_with_index do |element, index|
          return false unless (types[index] || types[-1]).instance?(element)
        end
        true
      end

      def iterable?
        true
      end

      def iterable_type
        PIterableType.new(TypeCalculator.singleton.infer_and_reduce_type(types))
      end

      # Returns the number of elements accepted [min, max] in the tuple
      def size_range
        if @size_type.nil?
          types_size = @types.size
          [types_size, types_size]
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
        @size_type.hash * 31 + @types.hash
      end

      def ==(o)
        self.class == o.class && @types == o.types && @size_type == o.size_type
      end

      DATA = PTupleType.new([PDataType::DEFAULT], PCollectionType::DEFAULT_SIZE)
      DEFAULT = PTupleType.new([])

      protected

      # @api private
      def _assignable?(o)
        return true if self == o
        s_types = types
        return true if s_types.empty? && (o.is_a?(PArrayType))
        size_s = size_type || PIntegerType.new(*size_range)

        if o.is_a?(PTupleType)
          size_o = o.size_type || PIntegerType.new(*o.size_range)

          # not assignable if the number of types in o is outside number of types in t1
          if size_s.assignable?(size_o)
            o_types = o.types
            o_types.size.times do |index|
              return false unless (s_types[index] || s_types[-1]).assignable?(o_types[index])
            end
            return true
          else
            return false
          end
        elsif o.is_a?(PArrayType)
          o_entry = o.element_type
          # Array of anything can not be assigned (unless tuple is tuple of anything) - this case
          # was handled at the top of this method.
          #
          return false if o_entry.nil?
          size_o = o.size_type || PCollectionType::DEFAULT_SIZE
          return false unless size_s.assignable?(size_o)
          [s_types.size, size_o.range[1]].min.times { |index| return false unless (s_types[index] || s_types[-1]).assignable?(o_entry) }
          true
        else
          false
        end
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

      def generalize
        return self if self == DEFAULT
        params_t = @param_types.nil? ? nil : @param_types.generalize
        block_t = @block_type.nil? ? nil : @block_type.generalize
        PCallableType.new(params_t, block_t)
      end

      def instance?(o)
        assignable?(TypeCalculator.infer(o))
      end

      # @api private
      def callable_args?(required_callable_t)
        # If the required callable is euqal or more specific than self, self is acceptable arguments
        required_callable_t.assignable?(self)
      end

      def kind_of_callable?(optional=true)
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
        @param_types.hash * 31 + @block_type.hash
      end

      def ==(o)
        self.class == o.class && @param_types == o.param_types && @block_type == o.block_type
      end

      DEFAULT = PCallableType.new(nil)

      protected

      # @api private
      def _assignable?(o)
        return false unless o.is_a?(PCallableType)
        # nil param_types means, any other Callable is assignable
        return true if @param_types.nil?

        # NOTE: these tests are made in reverse as it is calling the callable that is constrained
        # (it's lower bound), not its upper bound
        return false unless o.param_types.assignable?(@param_types)
        # names are ignored, they are just information
        # Blocks must be compatible
        this_block_t = @block_type || PUndefType::DEFAULT
        that_block_t = o.block_type || PUndefType::DEFAULT
        that_block_t.assignable?(this_block_t)
      end
    end

    # @api public
    #
    class PArrayType < PCollectionType

      # @api private
      def callable_args?(callable)
        param_t = callable.param_types
        block_t = callable.block_type
        # does not support calling with a block, but have to check that callable is ok with missing block
        (param_t.nil? || param_t.assignable?(self)) && (block_t.nil? || block_t.assignable(PUndefType::DEFAULT))
      end

      def generalize
        if self == DEFAULT
          self
        else
          PArrayType.new(element_type.nil? ? nil : element_type.generalize)
        end
      end

      def instance?(o)
        return false unless o.is_a?(Array)
        element_t = element_type
        return false unless element_t.nil? || o.all? {|element| element_t.instance?(element) }
        size_t = size_type
        size_t.nil? || size_t.instance?(o.size)
      end

      DATA = PArrayType.new(PDataType::DEFAULT, PCollectionType::DEFAULT_SIZE)
      DEFAULT = PArrayType.new(nil)
      EMPTY = PArrayType.new(PUnitType::DEFAULT, PCollectionType::ZERO_SIZE)

      protected

      # Array is assignable if o is an Array and o's element type is assignable, or if o is a Tuple
      # @api private
      def _assignable?(o)
        s_entry = element_type
        if o.is_a?(PTupleType)

          # Tuple of anything can not be assigned (unless array is tuple of anything) - this case
          # was handled at the top of this method.
          #
          return false if s_entry.nil?

          return false unless o.types.all? {|o_element_t| s_entry.assignable?(o_element_t) }
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
            o_entry = tuple_entry_at(o, o_from, o_to, index)
            return false unless s_entry.assignable?(o_entry)
          end
          # ... and so must the last, possibly optional (ranged) type
          s_entry.assignable?(o_ranged)
        elsif o.is_a?(PArrayType)
          super && (s_entry.nil? || s_entry.assignable?(o.element_type))
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
      end

      def generalize
        if self == DEFAULT || self == EMPTY
          self
        else
          key_t = @key_type
          key_t = key_t.generalize unless key_t.nil?
          value_t = element_type
          value_t = value_t.generalize unless value_t.nil?
          PHashType.new(key_t, value_t)
        end
      end

      def hash
        @key_type.hash * 31 + super
      end

      def instance?(o)
        return false unless o.is_a?(Hash)
        key_t = key_type
        element_t = element_type
        if (key_t.nil? || o.keys.all? {|key| key_t.instance?(key) }) &&
            (element_t.nil? || o.values.all? {|value| element_t.instance?(value) })
          size_t = size_type
          size_t.nil? || size_t.instance?(o.size)
        else
          false
        end
      end

      def iterable?
        true
      end

      def iterable_type
        if self == DEFAULT || self == EMPTY
          PIterableType.new(PTupleType.new([PAnyType::DEFAULT], TUPLE_SIZE))
        else
          PIterableType.new(PTupleType.new([@key_type, element_type], TUPLE_SIZE))
        end
      end

      def ==(o)
        super && @key_type == o.key_type
      end

      def is_the_empty_hash?
        self == EMPTY
      end

      DEFAULT = PHashType.new(nil, nil)
      TUPLE_SIZE = PIntegerType.new(2,2)
      DATA = PHashType.new(PScalarType::DEFAULT, PDataType::DEFAULT, DEFAULT_SIZE)
      EMPTY = PHashType.new(PUndefType::DEFAULT, PUndefType::DEFAULT, PIntegerType.new(0, 0))

      protected

      # Hash is assignable if o is a Hash and o's key and element types are assignable
      # @api private
      def _assignable?(o)
        case o
          when PHashType
            size_s = size_type
            return true if (size_s.nil? || size_s.from == 0) && o.is_the_empty_hash?
            return false unless (key_type.nil? || key_type.assignable?(o.key_type)) && (element_type.nil? || element_type.assignable?(o.element_type))
            super
          when PStructType
            # hash must accept String as key type
            # hash must accept all value types
            # hash must accept the size of the struct
            o_elements = o.elements
            (size_type || DEFAULT_SIZE).instance?(o_elements.size) &&
                o_elements.all? {|e| (key_type.nil? || key_type.instance?(e.name)) && (element_type.nil? || element_type.assignable?(e.value_type)) }
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

      def each
        if block_given?
          types.each { |t| yield t }
        else
          types.to_enum
        end
      end

      def generalize
        (self == DEFAULT || self == DATA) ? self : PVariantType.new(@types.map {|t| t.generalize})
      end

      def hash
        @types.hash
      end

      def instance?(o)
        # instance of variant if o is instance? of any of variant's types
        @types.any? { |type| type.instance?(o) }
      end

      def kind_of_callable?(optional = true)
        @types.all? { |type| type.kind_of_callable?(optional) }
      end

      def ==(o)
        # TODO: This special case doesn't look like it belongs here
        self.class == o.class && (@types | o.types).size == @types.size ||
            o.class == PDataType && self == DATA
      end

      # Variant compatible with the Data type.
      DATA = PVariantType.new([PHashType::DATA, PArrayType::DATA, PScalarType::DEFAULT, PUndefType::DEFAULT, PTupleType::DATA])

      DEFAULT = PVariantType.new([])

      protected

      # @api private
      def _assignable?(o)
        # Data is a specific variant
        o = DATA if o.is_a?(PDataType)
        if o.is_a?(PVariantType)
          # A variant is assignable if all of its options are assignable to one of this type's options
          return true if self == o
          o.types.all? do |other|
            # if the other is a Variant, all of its options, but be assignable to one of this type's options
            other = other.is_a?(PDataType) ? DATA : other
            if other.is_a?(PVariantType)
              assignable?(other)
            else
              types.any? {|option_t| option_t.assignable?(other) }
            end
          end
        else
          # A variant is assignable if o is assignable to any of its types
          types.any? { |option_t| option_t.assignable?(o) }
        end
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
        @runtime.hash * 31 + @runtime_type_name.hash
      end

      def ==(o)
        self.class == o.class && @runtime == o.runtime && @runtime_type_name == o.runtime_type_name
      end

      def instance?(o)
        assignable?(TypeCalculator.infer(o))
      end

      def iterable?
        c = class_from_string(@runtime_type_name)
        c.nil? ? false : c < Enumerable || c < Iterable
      end

      def iterable_type
        iterable? ? PIterableType.new(self) : nil
      end

      DEFAULT = PRuntimeType.new(nil)

      protected

      # Assignable if o's has the same runtime and the runtime name resolves to
      # a class that is the same or subclass of t1's resolved runtime type name
      # @api private
      def _assignable?(o)
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

      def instance?(o)
        assignable?(TypeCalculator.infer(o))
      end

      protected
      # @api private
      def _assignable?(o)
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
        11 * @class_name.hash
      end
      def ==(o)
        self.class == o.class && @class_name == o.class_name
      end

      DEFAULT = PHostClassType.new(nil)

      protected

      # @api private
      def _assignable?(o)
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
        @type_name.hash * 31 + @title.hash
      end

      def ==(o)
        self.class == o.class && @type_name == o.type_name && @title == o.title
      end

      DEFAULT = PResourceType.new(nil)

      protected

      # @api private
      def _assignable?(o)
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
    class POptionalType < PAnyType
      attr_reader :optional_type

      def initialize(optional_type)
        @optional_type = optional_type
      end

      def generalize
        @optional_type.nil? ? self : PType.new(@optional_type.generalize)
      end

      def hash
        7 * @optional_type.hash
      end

      def kind_of_callable?(optional=true)
          optional && !@optional_type.nil? && @optional_type.kind_of_callable?(optional)
      end

      def ==(o)
        self.class == o.class && @optional_type == o.optional_type
      end

      def instance?(o)
        PUndefType::DEFAULT.instance?(o) || (!optional_type.nil? && optional_type.instance?(o))
      end

      DEFAULT = POptionalType.new(nil)

      protected

      # @api private
      def _assignable?(o)
        return true if o.is_a?(PUndefType)
        return true if @optional_type.nil?
        if o.is_a?(POptionalType)
          @optional_type.assignable?(o.optional_type)
        else
          @optional_type.assignable?(o)
        end
      end
    end
  end
end

