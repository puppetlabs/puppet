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
  extend RGen::MetamodelBuilder::ModuleExtension

  class TypeModelObject < RGen::MetamodelBuilder::MMBase
    abstract
  end

  # Base type for all types except {Puppet::Pops::Types::PType PType}, the type of types.
  # @api public
  #
  class PAnyType < TypeModelObject
  end

  # A type that is assignable from the same types as its contained `type` except the
  # types assignable from {Puppet::Pops::Types::PUndefType}
  #
  # @api public
  #
  class PNotUndefType < PAnyType
    contains_one_uni 'type', PAnyType
  end

  # The type of types.
  # @api public
  #
  class PType < PAnyType
    contains_one_uni 'type', PAnyType
  end

  # @api public
  #
  class PUndefType < PAnyType
  end


  # A type private to the type system that describes "ignored type" - i.e. "I am what you are"
  # @api private
  #
  class  PUnitType < PAnyType
  end

  # @api public
  #
  class PDefaultType < PAnyType
  end

  # A flexible data type, being assignable to its subtypes as well as PArrayType and PHashType with element type assignable to PDataType.
  #
  # @api public
  #
  class PDataType < PAnyType
  end

  # A flexible type describing an any? of other types
  # @api public
  #
  class PVariantType < PAnyType
    contains_many_uni 'types', PAnyType, :lowerBound => 1
  end

  # Type that is PDataType compatible, but is not a PCollectionType.
  # @api public
  #
  class PScalarType < PAnyType
  end

  # A string type describing the set of strings having one of the given values
  # @api public
  #
  class PEnumType < PScalarType
    has_many_attr 'values', String, :lowerBound => 1
  end

  # @api public
  #
  class PNumericType < PScalarType
  end

  # @api public
  #
  class PIntegerType < PNumericType
    has_attr 'from', Integer, :lowerBound => 0
    has_attr 'to', Integer, :lowerBound => 0
  end

  # @api public
  #
  class PFloatType < PNumericType
    has_attr 'from', Float, :lowerBound => 0
    has_attr 'to', Float, :lowerBound => 0
  end

  # @api public
  #
  class PStringType < PScalarType
    has_many_attr 'values', String, :lowerBound => 0, :upperBound => -1, :unique => true
    contains_one_uni 'size_type', PIntegerType
  end

  # @api public
  #
  class PRegexpType < PScalarType
    has_attr 'pattern', String, :lowerBound => 1
    has_attr 'regexp', Object, :derived => true
  end

  # Represents a subtype of String that narrows the string to those matching the patterns
  # If specified without a pattern it is basically the same as the String type.
  #
  # @api public
  #
  class PPatternType < PScalarType
    contains_many_uni 'patterns', PRegexpType
  end

  # @api public
  #
  class PBooleanType < PScalarType
  end

  # @api public
  #
  class PCollectionType < PAnyType
    contains_one_uni 'element_type', PAnyType
    contains_one_uni 'size_type', PIntegerType
  end

  # @api public
  #
  class PStructElement < TypeModelObject
    # key_type must be either String[1] or Optional[String[1]] and the String[1] must
    # have a values collection with exactly one element
    contains_one_uni 'key_type', PAnyType, :lowerBound => 1
    contains_one_uni 'value_type', PAnyType
  end

  # @api public
  #
  class PStructType < PAnyType
    contains_many_uni 'elements', PStructElement, :lowerBound => 1
    has_attr 'hashed_elements', Object, :derived => true
  end

  # @api public
  #
  class PTupleType < PAnyType
    contains_many_uni 'types', PAnyType, :lowerBound => 1
    # If set, describes min and max required of the given types - if max > size of
    # types, the last type entry repeats
    #
    contains_one_uni 'size_type', PIntegerType, :lowerBound => 0
  end

  # @api public
  #
  class PCallableType < PAnyType
    # Types of parameters as a Tuple with required/optional count, or an Integer with min (required), max count
    contains_one_uni 'param_types', PAnyType, :lowerBound => 1

    # Although being an abstract type reference, only Callable, or all Callables wrapped in
    # Optional or Variant are supported
    # If not set, the meaning is that block is not supported.
    #
    contains_one_uni 'block_type', PAnyType, :lowerBound => 0
  end

  # @api public
  #
  class PArrayType < PCollectionType
  end

  # @api public
  #
  class PHashType < PCollectionType
    contains_one_uni 'key_type', PAnyType
  end

  RuntimeEnum = RGen::MetamodelBuilder::DataTypes::Enum.new(
    :name => 'RuntimeEnum',
    :literals => [:'ruby', ])

  # @api public
  #
  class PRuntimeType < PAnyType
    has_attr 'runtime', RuntimeEnum, :lowerBound => 1
    has_attr 'runtime_type_name', String
  end

  # Abstract representation of a type that can be placed in a Catalog.
  # @api public
  #
  class PCatalogEntryType < PAnyType
  end

  # Represents a (host-) class in the Puppet Language.
  # @api public
  #
  class PHostClassType < PCatalogEntryType
    has_attr 'class_name', String
  end

  # Represents a Resource Type in the Puppet Language
  # @api public
  #
  class PResourceType < PCatalogEntryType
    has_attr 'type_name', String
    has_attr 'title', String
  end

  # Represents a type that accept PUndefType instead of the type parameter
  # required_type - is a short hand for Variant[T, Undef]
  # @api public
  #
  class POptionalType < PAnyType
    contains_one_uni 'optional_type', PAnyType
  end

end
