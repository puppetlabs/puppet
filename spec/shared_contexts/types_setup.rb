shared_context 'types_setup' do

  # Do not include the special type Unit in this list
  def self.all_types
    [ Puppet::Pops::Types::PAnyType,
      Puppet::Pops::Types::PUndefType,
      Puppet::Pops::Types::PNotUndefType,
      Puppet::Pops::Types::PDataType,
      Puppet::Pops::Types::PScalarType,
      Puppet::Pops::Types::PStringType,
      Puppet::Pops::Types::PNumericType,
      Puppet::Pops::Types::PIntegerType,
      Puppet::Pops::Types::PFloatType,
      Puppet::Pops::Types::PRegexpType,
      Puppet::Pops::Types::PBooleanType,
      Puppet::Pops::Types::PCollectionType,
      Puppet::Pops::Types::PArrayType,
      Puppet::Pops::Types::PHashType,
      Puppet::Pops::Types::PIterableType,
      Puppet::Pops::Types::PIteratorType,
      Puppet::Pops::Types::PRuntimeType,
      Puppet::Pops::Types::PHostClassType,
      Puppet::Pops::Types::PResourceType,
      Puppet::Pops::Types::PPatternType,
      Puppet::Pops::Types::PEnumType,
      Puppet::Pops::Types::PVariantType,
      Puppet::Pops::Types::PStructType,
      Puppet::Pops::Types::PTupleType,
      Puppet::Pops::Types::PCallableType,
      Puppet::Pops::Types::PType,
      Puppet::Pops::Types::POptionalType,
      Puppet::Pops::Types::PDefaultType,
      Puppet::Pops::Types::PTypeReferenceType,
      Puppet::Pops::Types::PTypeAliasType,
      Puppet::Pops::Types::PSemVerType,
      Puppet::Pops::Types::PSemVerRangeType,
      Puppet::Pops::Types::PTimespanType,
      Puppet::Pops::Types::PTimestampType,
      Puppet::Pops::Types::PSensitiveType,
      Puppet::Pops::Types::PBinaryType,
    ]
  end
  def all_types
    self.class.all_types
  end

  def self.scalar_types
    # PVariantType is also scalar, if its types are all Scalar
    [
      Puppet::Pops::Types::PScalarType,
      Puppet::Pops::Types::PStringType,
      Puppet::Pops::Types::PNumericType,
      Puppet::Pops::Types::PIntegerType,
      Puppet::Pops::Types::PFloatType,
      Puppet::Pops::Types::PRegexpType,
      Puppet::Pops::Types::PBooleanType,
      Puppet::Pops::Types::PPatternType,
      Puppet::Pops::Types::PEnumType,
      Puppet::Pops::Types::PSemVerType,
      Puppet::Pops::Types::PSemVerRangeType,
      Puppet::Pops::Types::PTimespanType,
      Puppet::Pops::Types::PTimestampType,
    ]
  end
  def scalar_types
    self.class.scalar_types
  end

  def self.numeric_types
    # PVariantType is also numeric, if its types are all numeric
    [
      Puppet::Pops::Types::PNumericType,
      Puppet::Pops::Types::PIntegerType,
      Puppet::Pops::Types::PFloatType,
    ]
  end
  def numeric_types
    self.class.numeric_types
  end

  def self.string_types
    # PVariantType is also string type, if its types are all compatible
    [
      Puppet::Pops::Types::PStringType,
      Puppet::Pops::Types::PPatternType,
      Puppet::Pops::Types::PEnumType,
    ]
  end
  def string_types
    self.class.string_types
  end

  def self.collection_types
    # PVariantType is also string type, if its types are all compatible
    [
      Puppet::Pops::Types::PCollectionType,
      Puppet::Pops::Types::PHashType,
      Puppet::Pops::Types::PArrayType,
      Puppet::Pops::Types::PStructType,
      Puppet::Pops::Types::PTupleType,
    ]
  end
  def collection_types
    self.class.collection_types
  end

  def self.data_compatible_types
    result = scalar_types
    result << Puppet::Pops::Types::PDataType
    result << Puppet::Pops::Types::PArrayType::DATA
    result << Puppet::Pops::Types::PHashType::DATA
    result << Puppet::Pops::Types::PUndefType
    result << Puppet::Pops::Types::PNotUndefType.new(Puppet::Pops::Types::PDataType::DEFAULT)
    result << Puppet::Pops::Types::PTupleType.new([Puppet::Pops::Types::PDataType::DEFAULT], Puppet::Pops::Types::PIntegerType.new(0, nil))
    result
  end
  def data_compatible_types
    self.class.data_compatible_types
  end

  def type_from_class(c)
    c.is_a?(Class) ? c::DEFAULT : c
  end
end
