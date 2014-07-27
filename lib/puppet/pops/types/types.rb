require 'rgen/metamodel_builder'

# The Types model is a model of Puppet Language types.
# It consists of two parts; the meta-model expressed using RGen (in types_meta.rb) and this file which
# mixes in the implementation.
#
# @api public
#
module Puppet::Pops
  require 'puppet/pops/types/types_meta'

  # TODO: See PUP-2978 for possible performance optimization

  # Mix in implementation part of the Bindings Module
  module Types
    # Used as end in a range
    INFINITY = 1.0 / 0.0
    NEGATIVE_INFINITY = -INFINITY

    class TypeModelObject < RGen::MetamodelBuilder::MMBase
      include Puppet::Pops::Visitable
      include Puppet::Pops::Adaptable
      include Puppet::Pops::Containment
    end

    class PAnyType < TypeModelObject
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

    class PType < PAnyType
      module ClassModule
        def hash
          [self.class, type].hash
        end

        def ==(o)
          self.class == o.class && type == o.type
        end
      end
    end

    class PDataType < PAnyType
      module ClassModule
        def ==(o)
          self.class == o.class ||
            o.class == PVariantType && o == Puppet::Pops::Types::TypeCalculator.data_variant()
        end
      end
    end

    class PVariantType < PAnyType
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

    class PEnumType < PScalarType
      module ClassModule
        def hash
          [self.class, Set.new(self.values)].hash
        end

        def ==(o)
          self.class == o.class && Set.new(values) == Set.new(o.values)
        end
      end
    end

    class PIntegerType < PNumericType
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

    class PFloatType < PNumericType
      module ClassModule
        def hash
          [self.class, from, to].hash
        end

        def ==(o)
          self.class == o.class && from == o.from && to == o.to
        end
      end
    end

    class PStringType < PScalarType
      module ClassModule

        def hash
          [self.class, self.size_type, Set.new(self.values)].hash
        end

        def ==(o)
          self.class == o.class && self.size_type == o.size_type && Set.new(values) == Set.new(o.values)
        end
      end
    end

    class PRegexpType < PScalarType
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

    class PPatternType < PScalarType
      module ClassModule

        def hash
          [self.class, Set.new(patterns)].hash
        end

        def ==(o)
          self.class == o.class && Set.new(patterns) == Set.new(o.patterns)
        end
      end
    end

    class PCollectionType < PAnyType
      module ClassModule
        # Returns an array with from (min) size to (max) size
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

    class PStructElement < TypeModelObject
      module ClassModule
        def hash
          [self.class, type, name].hash
        end

        def ==(o)
          self.class == o.class && type == o.type && name == o.name
        end
      end
    end


    class PStructType < PAnyType
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

    class PTupleType < PAnyType
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

    class PCallableType < PAnyType
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

    class PHashType < PCollectionType
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


    class PRuntimeType < PAnyType
      module ClassModule
        def hash
          [self.class, runtime, runtime_type_name].hash
        end

        def ==(o)
          self.class == o.class && runtime == o.runtime && runtime_type_name == o.runtime_type_name 
        end
      end
    end

    class PHostClassType < PCatalogEntryType
      module ClassModule
        def hash
          [self.class, class_name].hash
        end
        def ==(o)
          self.class == o.class && class_name == o.class_name
        end
      end
    end

    class PResourceType < PCatalogEntryType
      module ClassModule
        def hash
          [self.class, type_name, title].hash
        end
        def ==(o)
          self.class == o.class && type_name == o.type_name && title == o.title
        end
      end
    end

    class POptionalType < PAnyType
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
end
