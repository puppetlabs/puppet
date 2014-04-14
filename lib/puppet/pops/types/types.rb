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
module Puppet::Pops::Types
  # Used as end in a range
  INFINITY = 1.0 / 0.0
  NEGATIVE_INFINITY = -INFINITY

  class PAbstractType < Puppet::Pops::Model::PopsObject
    abstract
    module ClassModule
      # Produce a deep copy of the type
      def copy
        Marshal.load(Marshal.dump(self))
      end

      def hash
        self.class.hash
      end

      def ==(o)
        self.class == o.class
      end

      alias eql? ==

      def to_s
        Puppet::Pops::Types::TypeCalculator.string(self)
      end
    end
  end

  # The type of types.
  # @api public
  class PType < PAbstractType
    contains_one_uni 'type', PAbstractType
    module ClassModule
      def hash
        [self.class, type].hash
      end

      def ==(o)
        self.class == o.class && type == o.type
      end
    end
  end

  # Base type for all types except {Puppet::Pops::Types::PType PType}, the type of types.
  # @api public
  class PObjectType < PAbstractType

    module ClassModule
    end

  end

  # @api public
  class PNilType < PObjectType
  end

  # A flexible data type, being assignable to its subtypes as well as PArrayType and PHashType with element type assignable to PDataType.
  #
  # @api public
  class PDataType < PObjectType
    module ClassModule
      def ==(o)
        self.class == o.class ||
          o.class == PVariantType && o == Puppet::Pops::Types::TypeCalculator.data_variant()
      end
    end
  end

  # A flexible type describing an any? of other types
  # @api public
  class PVariantType < PObjectType
    contains_many_uni 'types', PAbstractType, :lowerBound => 1

    module ClassModule

      def hash
        [self.class, Set.new(self.types)].hash
      end

      def ==(o)
        (self.class == o.class && Set.new(types) == Set.new(o.types)) ||
          (o.class == PDataType && self == Puppet::Pops::Types::TypeCalculator.data_variant())
      end
    end
  end

  # Type that is PDataType compatible, but is not a PCollectionType.
  # @api public
  class PScalarType < PObjectType
  end

  # A string type describing the set of strings having one of the given values
  #
  class PEnumType < PScalarType
    has_many_attr 'values', String, :lowerBound => 1

    module ClassModule
      def hash
        [self.class, Set.new(self.values)].hash
      end

      def ==(o)
        self.class == o.class && Set.new(values) == Set.new(o.values)
      end
    end
  end

  # @api public
  class PNumericType < PScalarType
  end

  # @api public
  class PIntegerType < PNumericType
    has_attr 'from', Integer, :lowerBound => 0
    has_attr 'to', Integer, :lowerBound => 0

    module ClassModule
      # The integer type is enumerable when it defines a range
      include Enumerable

      # Returns Float.Infinity if one end of the range is unbound
      def size
        return INFINITY if from.nil? || to.nil?
        1+(to-from).abs
      end

      # Returns the range as an array ordered so the smaller number is always first.
      # The number may be Infinity or -Infinity.
      def range
        f = from || NEGATIVE_INFINITY
        t = to || INFINITY
        if f < t
          [f, t]
        else
          [t,f]
        end
      end

      # Returns Enumerator if no block is given
      # Returns self if size is infinity (does not yield)
      def each
        return self.to_enum unless block_given?
        return nil if from.nil? || to.nil?
        if to < from
          from.downto(to) {|x| yield x }
        else
          from.upto(to) {|x| yield x }
        end
      end

      def hash
        [self.class, from, to].hash
      end

      def ==(o)
        self.class == o.class && from == o.from && to == o.to
      end
    end
  end

  # @api public
  class PFloatType < PNumericType
    has_attr 'from', Float, :lowerBound => 0
    has_attr 'to', Float, :lowerBound => 0

    module ClassModule
      def hash
        [self.class, from, to].hash
      end

      def ==(o)
        self.class == o.class && from == o.from && to == o.to
      end
    end
  end

  # @api public
  class PStringType < PScalarType
    has_many_attr 'values', String, :lowerBound => 0, :upperBound => -1, :unique => true
    contains_one_uni 'size_type', PIntegerType

    module ClassModule

      def hash
        [self.class, self.size_type, Set.new(self.values)].hash
      end

      def ==(o)
        self.class == o.class && self.size_type == o.size_type && Set.new(values) == Set.new(o.values)
      end
    end
  end

  # @api public
  class PRegexpType < PScalarType
    has_attr 'pattern', String, :lowerBound => 1
    has_attr 'regexp', Object, :derived => true

    module ClassModule
      def regexp_derived
        @_regexp = Regexp.new(pattern) unless @_regexp && @_regexp.source == pattern
        @_regexp
      end

      def hash
        [self.class, pattern].hash
      end

      def ==(o)
        self.class == o.class && pattern == o.pattern
      end
    end
  end

  # Represents a subtype of String that narrows the string to those matching the patterns
  # If specified without a pattern it is basically the same as the String type.
  #
  # @api public
  class PPatternType < PScalarType
    contains_many_uni 'patterns', PRegexpType

    module ClassModule

      def hash
        [self.class, Set.new(patterns)].hash
      end

      def ==(o)
        self.class == o.class && Set.new(patterns) == Set.new(o.patterns)
      end
    end
  end

  # @api public
  class PBooleanType < PScalarType
  end

  # @api public
  class PCollectionType < PObjectType
    contains_one_uni 'element_type', PAbstractType
    contains_one_uni 'size_type', PIntegerType

    module ClassModule
      # Returns an array with from (min) size to (max) size
      # A negative range value in from is 
      def size_range
        return [0, INFINITY] if size_type.nil?
        f = size_type.from || 0
        t = size_type.to || INFINITY
        if f < t
          [f, t]
        else
          [t,f]
        end
      end

      def hash
        [self.class, element_type, size_type].hash
      end

      def ==(o)
        self.class == o.class && element_type == o.element_type && size_type == o.size_type
      end
    end
  end

  class PStructElement < Puppet::Pops::Model::PopsObject
    has_attr 'name', String, :lowerBound => 1
    contains_one_uni 'type', PAbstractType

    module ClassModule
      def hash
        [self.class, type, name].hash
      end

      def ==(o)
        self.class == o.class && type == o.type && name == o.name
      end
    end
  end

  # @api public
  class PStructType < PObjectType
    contains_many_uni 'elements', PStructElement, :lowerBound => 1
    has_attr 'hashed_elements', Object, :derived => true

    module ClassModule
      def hashed_elements_derived
        @_hashed ||= elements.reduce({}) {|memo, e| memo[e.name] = e.type; memo }
        @_hashed
      end

      def clear_hashed_elements
        @_hashed = nil
      end

      def hash
        [self.class, Set.new(elements)].hash
      end

      def ==(o)
        self.class == o.class && hashed_elements == o.hashed_elements
      end
    end
  end

  # @api public
  class PTupleType < PObjectType
    contains_many_uni 'types', PAbstractType, :lowerBound => 1
    # If set, describes min and max required of the given types - if max > size of
    # types, the last type entry repeats
    #
    contains_one_uni 'size_type', PIntegerType, :lowerBound => 0

    module ClassModule
      # Returns the number of elements accepted [min, max] in the tuple
      def size_range
        types_size = types.size
        size_type.nil? ? [types_size, types_size] : size_type.range
      end

      # Returns the number of accepted occurrences [min, max] of the last type in the tuple
      # The defaults is [1,1]
      #
      def repeat_last_range
        types_size = types.size
        if size_type.nil?
          return [1, 1]
        end
        from, to = size_type.range()
        min = from - (types_size-1)
        min = min <= 0 ? 0 : min
        max = to - (types_size-1)
        [min, max]
      end

      def hash
        [self.class, size_type, Set.new(types)].hash
      end

      def ==(o)
        self.class == o.class && types == o.types && size_type == o.size_type
      end
    end
  end

  class PCallableType < PObjectType
    # Types of parameters and required/optional count
    contains_one_uni 'param_types', PTupleType, :lowerBound => 1

    # Although being an abstract type reference, only PAbstractCallable, and Optional[Callable] are supported
    # If not set, the meaning is that block is not supported.
    #
    contains_one_uni 'block_type', PAbstractType, :lowerBound => 0

    module ClassModule
      # Returns the number of accepted arguments [min, max]
      def size_range
        param_types.size_range
      end

      # Returns the number of accepted arguments for the last parameter type [min, max]
      #
      def last_range
        param_types.repeat_last_range
      end

      # Range [0,0], [0,1], or [1,1] for the block
      #
      def block_range
        case block_type
        when Puppet::Pops::Types::POptionalType
          [0,1]
        when Puppet::Pops::Types::PVariantType, Puppet::Pops::Types::PCallableType
          [1,1]
        else
          [0,0]
        end
      end

      def hash
        [self.class, Set.new(param_types), block_type].hash
      end

      def ==(o)
        self.class == o.class && args_type == o.args_type && block_type == o.block_type
      end
    end
  end

  # @api public
  class PArrayType < PCollectionType
    module ClassModule
      def hash
        [self.class, self.element_type, self.size_type].hash
      end

      def ==(o)
        self.class == o.class && self.element_type == o.element_type && self.size_type == o.size_type
      end
    end
  end

  # @api public
  class PHashType < PCollectionType
    contains_one_uni 'key_type', PAbstractType
    module ClassModule
      def hash
        [self.class, key_type, self.element_type, self.size_type].hash
      end

      def ==(o)
        self.class        == o.class         &&
        key_type          == o.key_type      &&
        self.element_type == o.element_type  &&
        self.size_type    == o.size_type
      end
    end
  end

  # @api public
  class PRubyType < PObjectType
    has_attr 'ruby_class', String
    module ClassModule
      def hash
        [self.class, ruby_class].hash
      end

      def ==(o)
        self.class == o.class && ruby_class == o.ruby_class
      end
    end
  end

  # Abstract representation of a type that can be placed in a Catalog.
  # @api public
  #
  class PCatalogEntryType < PObjectType
  end

  # Represents a (host-) class in the Puppet Language.
  # @api public
  #
  class PHostClassType < PCatalogEntryType
    has_attr 'class_name', String
    # contains_one_uni 'super_type', PHostClassType
    module ClassModule
      def hash
        [self.class, class_name].hash
      end
      def ==(o)
        self.class == o.class && class_name == o.class_name
      end
    end
  end

  # Represents a Resource Type in the Puppet Language
  # @api public
  #
  class PResourceType < PCatalogEntryType
    has_attr 'type_name', String
    has_attr 'title', String
    module ClassModule
      def hash
        [self.class, type_name, title].hash
      end
      def ==(o)
        self.class == o.class && type_name == o.type_name && title == o.title
      end
    end
  end

  # Represents a type that accept PNilType instead of the type parameter
  # required_type - is a short hand for Variant[T, Undef]
  #
  class POptionalType < PAbstractType
    contains_one_uni 'optional_type', PAbstractType
    module ClassModule
      def hash
        [self.class, optional_type].hash
      end

      def ==(o)
        self.class == o.class && optional_type == o.optional_type
      end
    end
  end

end
