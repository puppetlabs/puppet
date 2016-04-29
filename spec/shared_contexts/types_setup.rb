shared_context 'types_setup' do

  # Do not include the special type Unit in this list
  def all_types
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
    ]
  end

  def scalar_types
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
    ]
  end

  def numeric_types
    # PVariantType is also numeric, if its types are all numeric
    [
      Puppet::Pops::Types::PNumericType,
      Puppet::Pops::Types::PIntegerType,
      Puppet::Pops::Types::PFloatType,
    ]
  end

  def string_types
    # PVariantType is also string type, if its types are all compatible
    [
      Puppet::Pops::Types::PStringType,
      Puppet::Pops::Types::PPatternType,
      Puppet::Pops::Types::PEnumType,
    ]
  end

  def collection_types
    # PVariantType is also string type, if its types are all compatible
    [
      Puppet::Pops::Types::PCollectionType,
      Puppet::Pops::Types::PHashType,
      Puppet::Pops::Types::PArrayType,
      Puppet::Pops::Types::PStructType,
      Puppet::Pops::Types::PTupleType,
    ]
  end

  def data_compatible_types
    result = scalar_types
    result << Puppet::Pops::Types::PDataType
    result << array_t(types::PDataType::DEFAULT)
    result << types::TypeFactory.hash_of_data
    result << Puppet::Pops::Types::PUndefType
    result << not_undef_t(types::PDataType.new)
    result << constrained_tuple_t(range_t(0, nil), types::PDataType::DEFAULT)
    result
  end

  def type_from_class(c)
    c.is_a?(Class) ? c::DEFAULT : c
  end
end
