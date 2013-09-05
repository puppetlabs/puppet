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
    module ClassModule
      def [](pattern)
        Regexp.new(pattern)
      end
    end
  end

  # @api public
  class PBooleanType < PLiteralType
  end

  # @api public
  class PCollectionType < PObjectType
    contains_one_uni 'element_type', PAbstractType
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
    contains_one_uni 'key_type', PAbstractType
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
        [self.class, host_class].hash
      end
      def ==(o)
        self.class == o.class && class_name == o.class_name
      end
      def [](*class_names)
        raise ArgumentError, "Cannot create new Class references from a specific Class reference" unless class_name.nil?
        return self if class_names.size == 0
        result = class_names.collect {|n| x = self.class.new; x.class_name = n; x}
        result.size == 1 ? result.pop : result
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
      def [](*titles)
        raise ArgumentError, "Cannot create new Resource references from a specific Resource reference" unless title.nil?
        return self if titles.size == 0
        raise ArgumentError, "A Resource reference without type name can not produce Resource references." if type_name.nil?
        result = titles.collect {|t| x = self.class.new; x.type_name = type_name; x.title = t; x}
        result.size == 1 ? result.pop : result
      end
    end
  end

end
