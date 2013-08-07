require 'rgen/metamodel_builder'

# The Types model is a model of Puppet Language types.
#
# The exact relationship between types is not visible in this model wrt. the PDataType which is an abstraction
# of Literal, Array[Data], and Hash[Literal, Data] nested to any depth. This means it is not possible to
# infer the type by simply looking at the inheritance hierarchy. The {Puppet::Pops::Types::TypeCalculator} should
# be used to answer questions about types. The {Puppet::Pops::Types::TypeFactory} should be used to create an instance
# of a type whenever one is needed.
#
# @api public
#
module Puppet::Pops::Types

  # The type of types.
  # @api public
  class PType < Puppet::Pops::Model::PopsObject
  end

  # Base type for all types except {Puppet::Pops::Types::PType PType}, the type of types.
  # @api public
  class PObjectType < Puppet::Pops::Model::PopsObject

    module ClassModule
      def hash
        self.class.hash
      end

      def ==(o)
        self.class == o.class
      end

      alias eql? ==
    end

  end

  # @api public
  class PNilType < PObjectType
  end

  # A flexible data type, being assignable to its subtypes as well as PArrayType and PHashType with element type assignable to PDataType.
  #
  # @api public
  class PDataType < PObjectType
  end

  # Type that is PDataType compatible, but is not a PCollectionType.
  # @api public
  class PLiteralType < PDataType
  end

  # @api public
  class PStringType < PLiteralType
  end

  # @api public
  class PNumericType < PLiteralType
  end

  # @api public
  class PIntegerType < PNumericType
  end

  # @api public
  class PFloatType < PNumericType
  end

  # @api public
  class PPatternType < PLiteralType
  end

  # @api public
  class PBooleanType < PLiteralType
  end

  # @api public
  class PCollectionType < PObjectType
    contains_one_uni 'element_type', PObjectType
    module ClassModule
      def hash
        [self.class, element_type].hash
      end

      def ==(o)
        self.class == o.class && element_type == o.element_type
      end
    end
  end

  # @api public
  class PArrayType < PCollectionType
    module ClassModule
      def hash
        [self.class, element_type].hash
      end

      def ==(o)
        self.class == o.class && element_type == o.element_type
      end
    end
  end

  # @api public
  class PHashType < PCollectionType
    contains_one_uni 'key_type', PObjectType
    module ClassModule
      def hash
        [self.class, key_type, element_type].hash
      end

      def ==(o)
        self.class == o.class && key_type == o.key_type && element_type == o.element_type
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
end
