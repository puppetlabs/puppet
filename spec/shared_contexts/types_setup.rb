shared_context 'types_setup' do

  # Do not include the special type Unit in this list
  # Do not include the type Variant in this list as it needs to be parameterized to be meaningful
  def self.all_types
    [ Puppet::Pops::Types::PAnyType,
      Puppet::Pops::Types::PUndefType,
      Puppet::Pops::Types::PNotUndefType,
      Puppet::Pops::Types::PScalarType,
      Puppet::Pops::Types::PScalarDataType,
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
      Puppet::Pops::Types::PClassType,
      Puppet::Pops::Types::PResourceType,
      Puppet::Pops::Types::PPatternType,
      Puppet::Pops::Types::PEnumType,
      Puppet::Pops::Types::PStructType,
      Puppet::Pops::Types::PTupleType,
      Puppet::Pops::Types::PCallableType,
      Puppet::Pops::Types::PTypeType,
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
      Puppet::Pops::Types::PInitType,
      Puppet::Pops::Types::PURIType,
    ]
  end
  def all_types
    self.class.all_types
  end

  # Do not include the Variant type in this list - while it is abstract it is also special in that
  # it must be parameterized to be meaningful.
  #
  def self.abstract_types
    [ Puppet::Pops::Types::PAnyType,
      Puppet::Pops::Types::PCallableType,
      Puppet::Pops::Types::PEnumType,
      Puppet::Pops::Types::PClassType,
      Puppet::Pops::Types::PDefaultType,
      Puppet::Pops::Types::PCollectionType,
      Puppet::Pops::Types::PInitType,
      Puppet::Pops::Types::PIterableType,
      Puppet::Pops::Types::PIteratorType,
      Puppet::Pops::Types::PNotUndefType,
      Puppet::Pops::Types::PResourceType,
      Puppet::Pops::Types::PRuntimeType,
      Puppet::Pops::Types::POptionalType,
      Puppet::Pops::Types::PPatternType,
      Puppet::Pops::Types::PScalarType,
      Puppet::Pops::Types::PScalarDataType,
      Puppet::Pops::Types::PUndefType,
      Puppet::Pops::Types::PTypeReferenceType,
      Puppet::Pops::Types::PTypeAliasType,
    ]
  end
  def abstract_types
    self.class.abstract_types
  end

  # Internal types. Not meaningful in pp
  def self.internal_types
    [ Puppet::Pops::Types::PTypeReferenceType,
      Puppet::Pops::Types::PTypeAliasType,
    ]
  end
  def internal_types
    self.class.internal_types
  end


  def self.scalar_data_types
    # PVariantType is also scalar data, if its types are all ScalarData
    [
      Puppet::Pops::Types::PScalarDataType,
      Puppet::Pops::Types::PStringType,
      Puppet::Pops::Types::PNumericType,
      Puppet::Pops::Types::PIntegerType,
      Puppet::Pops::Types::PFloatType,
      Puppet::Pops::Types::PBooleanType,
      Puppet::Pops::Types::PEnumType,
      Puppet::Pops::Types::PPatternType,
    ]
  end
  def scalar_data_types
    self.class.scalar_data_types
  end


  def self.scalar_types
    # PVariantType is also scalar, if its types are all Scalar
    [
      Puppet::Pops::Types::PScalarType,
      Puppet::Pops::Types::PScalarDataType,
      Puppet::Pops::Types::PStringType,
      Puppet::Pops::Types::PNumericType,
      Puppet::Pops::Types::PIntegerType,
      Puppet::Pops::Types::PFloatType,
      Puppet::Pops::Types::PRegexpType,
      Puppet::Pops::Types::PBooleanType,
      Puppet::Pops::Types::PPatternType,
      Puppet::Pops::Types::PEnumType,
      Puppet::Pops::Types::PSemVerType,
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
    tf = Puppet::Pops::Types::TypeFactory
    result = scalar_data_types
    result << Puppet::Pops::Types::PArrayType.new(tf.data)
    result << Puppet::Pops::Types::PHashType.new(Puppet::Pops::Types::PStringType::DEFAULT, tf.data)
    result << Puppet::Pops::Types::PUndefType
    result << Puppet::Pops::Types::PTupleType.new([tf.data])
    result
  end
  def data_compatible_types
    self.class.data_compatible_types
  end

  def self.rich_data_compatible_types
    tf = Puppet::Pops::Types::TypeFactory
    result = scalar_types
    result << Puppet::Pops::Types::PArrayType.new(tf.rich_data)
    result << Puppet::Pops::Types::PHashType.new(tf.rich_data_key, tf.rich_data)
    result << Puppet::Pops::Types::PUndefType
    result << Puppet::Pops::Types::PDefaultType
    result << Puppet::Pops::Types::PURIType
    result << Puppet::Pops::Types::PTupleType.new([tf.rich_data])
    result << Puppet::Pops::Types::PObjectType
    result
  end
  def rich_data_compatible_types
    self.class.rich_data_compatible_types
  end

  def self.type_from_class(c)
    c.is_a?(Class) ? c::DEFAULT : c
  end
  def type_from_class(c)
    self.class.type_from_class(c)
  end
end
