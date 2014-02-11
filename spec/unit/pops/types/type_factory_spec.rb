require 'spec_helper'
require 'puppet/pops'

describe 'The type factory' do
  context 'when creating' do
    it 'integer() returns PIntegerType' do
      Puppet::Pops::Types::TypeFactory.integer().class().should == Puppet::Pops::Types::PIntegerType
    end

    it 'float() returns PFloatType' do
      Puppet::Pops::Types::TypeFactory.float().class().should == Puppet::Pops::Types::PFloatType
    end

    it 'string() returns PStringType' do
      Puppet::Pops::Types::TypeFactory.string().class().should == Puppet::Pops::Types::PStringType
    end

    it 'boolean() returns PBooleanType' do
      Puppet::Pops::Types::TypeFactory.boolean().class().should == Puppet::Pops::Types::PBooleanType
    end

    it 'pattern() returns PPatternType' do
      Puppet::Pops::Types::TypeFactory.pattern().class().should == Puppet::Pops::Types::PPatternType
    end

    it 'regexp() returns PRegexpType' do
      Puppet::Pops::Types::TypeFactory.regexp().class().should == Puppet::Pops::Types::PRegexpType
    end

    it 'enum() returns PEnumType' do
      Puppet::Pops::Types::TypeFactory.enum().class().should == Puppet::Pops::Types::PEnumType
    end

    it 'variant() returns PVariantType' do
      Puppet::Pops::Types::TypeFactory.variant().class().should == Puppet::Pops::Types::PVariantType
    end

    it 'scalar() returns PScalarType' do
      Puppet::Pops::Types::TypeFactory.scalar().class().should == Puppet::Pops::Types::PScalarType
    end

    it 'data() returns PDataType' do
      Puppet::Pops::Types::TypeFactory.data().class().should == Puppet::Pops::Types::PDataType
    end

    it 'optional() returns POptionalType' do
      Puppet::Pops::Types::TypeFactory.optional().class().should == Puppet::Pops::Types::POptionalType
    end

    it 'collection() returns PCollectionType' do
      Puppet::Pops::Types::TypeFactory.collection().class().should == Puppet::Pops::Types::PCollectionType
    end

    it 'catalog_entry() returns PCatalogEntryType' do
      Puppet::Pops::Types::TypeFactory.catalog_entry().class().should == Puppet::Pops::Types::PCatalogEntryType
    end

    it 'struct() returns PStructType' do
      Puppet::Pops::Types::TypeFactory.struct().class().should == Puppet::Pops::Types::PStructType
    end

    it 'tuple() returns PTupleType' do
      Puppet::Pops::Types::TypeFactory.tuple().class().should == Puppet::Pops::Types::PTupleType
    end

    it 'undef() returns PNilType' do
      Puppet::Pops::Types::TypeFactory.undef().class().should == Puppet::Pops::Types::PNilType
    end

    it 'range(to, from) returns PIntegerType' do
      t = Puppet::Pops::Types::TypeFactory.range(1,2)
      t.class().should == Puppet::Pops::Types::PIntegerType
      t.from.should == 1
      t.to.should == 2
    end

    it 'range(default, default) returns PIntegerType' do
      t = Puppet::Pops::Types::TypeFactory.range(:default,:default)
      t.class().should == Puppet::Pops::Types::PIntegerType
      t.from.should == nil
      t.to.should == nil
    end

    it 'float_range(to, from) returns PFloatType' do
      t = Puppet::Pops::Types::TypeFactory.float_range(1.0, 2.0)
      t.class().should == Puppet::Pops::Types::PFloatType
      t.from.should == 1.0
      t.to.should == 2.0
    end

    it 'float_range(default, default) returns PFloatType' do
      t = Puppet::Pops::Types::TypeFactory.float_range(:default, :default)
      t.class().should == Puppet::Pops::Types::PFloatType
      t.from.should == nil
      t.to.should == nil
    end

    it 'resource() creates a generic PResourceType' do
      pr = Puppet::Pops::Types::TypeFactory.resource()
      pr.class().should == Puppet::Pops::Types::PResourceType
      pr.type_name.should == nil
    end

    it 'resource(x) creates a PResourceType[x]' do
      pr = Puppet::Pops::Types::TypeFactory.resource('x')
      pr.class().should == Puppet::Pops::Types::PResourceType
      pr.type_name.should == 'x'
    end

    it 'host_class() creates a generic PHostClassType' do
      hc = Puppet::Pops::Types::TypeFactory.host_class()
      hc.class().should == Puppet::Pops::Types::PHostClassType
      hc.class_name.should == nil
    end

    it 'host_class(x) creates a PHostClassType[x]' do
      hc = Puppet::Pops::Types::TypeFactory.host_class('x')
      hc.class().should == Puppet::Pops::Types::PHostClassType
      hc.class_name.should == 'x'
    end

    it 'array_of(fixnum) returns PArrayType[PIntegerType]' do
      at = Puppet::Pops::Types::TypeFactory.array_of(1)
      at.class().should == Puppet::Pops::Types::PArrayType
      at.element_type.class.should == Puppet::Pops::Types::PIntegerType
    end

    it 'array_of(PIntegerType) returns PArrayType[PIntegerType]' do
      at = Puppet::Pops::Types::TypeFactory.array_of(Puppet::Pops::Types::PIntegerType.new())
      at.class().should == Puppet::Pops::Types::PArrayType
      at.element_type.class.should == Puppet::Pops::Types::PIntegerType
    end

    it 'array_of_data returns PArrayType[PDataType]' do
      at = Puppet::Pops::Types::TypeFactory.array_of_data
      at.class().should == Puppet::Pops::Types::PArrayType
      at.element_type.class.should == Puppet::Pops::Types::PDataType
    end

    it 'hash_of_data returns PHashType[PScalarType,PDataType]' do
      ht = Puppet::Pops::Types::TypeFactory.hash_of_data
      ht.class().should == Puppet::Pops::Types::PHashType
      ht.key_type.class.should == Puppet::Pops::Types::PScalarType
      ht.element_type.class.should == Puppet::Pops::Types::PDataType
    end

    it 'ruby(1) returns PRubyType[\'Fixnum\']' do
      ht = Puppet::Pops::Types::TypeFactory.ruby(1)
      ht.class().should == Puppet::Pops::Types::PRubyType
      ht.ruby_class.should == 'Fixnum'
    end

    it 'a size constrained collection can be created from array' do
      t = Puppet::Pops::Types::TypeFactory.array_of_data()
      Puppet::Pops::Types::TypeFactory.constrain_size(t, 1,2).should == t
      t.size_type.class.should == Puppet::Pops::Types::PIntegerType
      t.size_type.from.should == 1
      t.size_type.to.should == 2
    end

    it 'a size constrained collection can be created from hash' do
      t = Puppet::Pops::Types::TypeFactory.hash_of_data()
      Puppet::Pops::Types::TypeFactory.constrain_size(t, 1,2).should == t
      t.size_type.class.should == Puppet::Pops::Types::PIntegerType
      t.size_type.from.should == 1
      t.size_type.to.should == 2
    end
  end
end
