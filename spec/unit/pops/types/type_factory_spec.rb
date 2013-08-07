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

    it 'literal() returns PLiteralType' do
      Puppet::Pops::Types::TypeFactory.literal().class().should == Puppet::Pops::Types::PLiteralType
    end

    it 'data() returns PDataType' do
      Puppet::Pops::Types::TypeFactory.data().class().should == Puppet::Pops::Types::PDataType
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

    it 'hash_of_data returns PHashType[PLiteralType,PDataType]' do
      ht = Puppet::Pops::Types::TypeFactory.hash_of_data
      ht.class().should == Puppet::Pops::Types::PHashType
      ht.key_type.class.should == Puppet::Pops::Types::PLiteralType
      ht.element_type.class.should == Puppet::Pops::Types::PDataType
    end

    it 'ruby(1) returns PRubyType[\'Fixnum\']' do
      ht = Puppet::Pops::Types::TypeFactory.ruby(1)
      ht.class().should == Puppet::Pops::Types::PRubyType
      ht.ruby_class.should == 'Fixnum'
    end
  end
end
