require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Types
describe 'The type factory' do
  context 'when creating' do
    it 'integer() returns PIntegerType' do
      expect(TypeFactory.integer().class()).to eq(PIntegerType)
    end

    it 'float() returns PFloatType' do
      expect(TypeFactory.float().class()).to eq(PFloatType)
    end

    it 'string() returns PStringType' do
      expect(TypeFactory.string().class()).to eq(PStringType)
    end

    it 'boolean() returns PBooleanType' do
      expect(TypeFactory.boolean().class()).to eq(PBooleanType)
    end

    it 'pattern() returns PPatternType' do
      expect(TypeFactory.pattern().class()).to eq(PPatternType)
    end

    it 'regexp() returns PRegexpType' do
      expect(TypeFactory.regexp().class()).to eq(PRegexpType)
    end

    it 'enum() returns PEnumType' do
      expect(TypeFactory.enum().class()).to eq(PEnumType)
    end

    it 'variant() returns PVariantType' do
      expect(TypeFactory.variant().class()).to eq(PVariantType)
    end

    it 'scalar() returns PScalarType' do
      expect(TypeFactory.scalar().class()).to eq(PScalarType)
    end

    it 'data() returns PDataType' do
      expect(TypeFactory.data().class()).to eq(PDataType)
    end

    it 'optional() returns POptionalType' do
      expect(TypeFactory.optional().class()).to eq(POptionalType)
    end

    it 'collection() returns PCollectionType' do
      expect(TypeFactory.collection().class()).to eq(PCollectionType)
    end

    it 'catalog_entry() returns PCatalogEntryType' do
      expect(TypeFactory.catalog_entry().class()).to eq(PCatalogEntryType)
    end

    it 'struct() returns PStructType' do
      expect(TypeFactory.struct().class()).to eq(PStructType)
    end

    it "object() returns PObjectType" do
      expect(TypeFactory.object.class).to eq(PObjectType)
    end

    it 'tuple() returns PTupleType' do
      expect(TypeFactory.tuple.class()).to eq(PTupleType)
    end

    it 'undef() returns PUndefType' do
      expect(TypeFactory.undef().class()).to eq(PUndefType)
    end

    it 'type_alias() returns PTypeAliasType' do
      expect(TypeFactory.type_alias().class()).to eq(PTypeAliasType)
    end

    it 'sem_ver() returns PSemVerType' do
      expect(TypeFactory.sem_ver.class).to eq(PSemVerType)
    end

    it 'sem_ver(r1, r2) returns constrained PSemVerType' do
      expect(TypeFactory.sem_ver('1.x', '3.x').ranges).to include(Semantic::VersionRange.parse('1.x'), Semantic::VersionRange.parse('3.x'))
    end

    it 'sem_ver_range() returns PSemVerRangeType' do
      expect(TypeFactory.sem_ver_range.class).to eq(PSemVerRangeType)
    end

    it 'default() returns PDefaultType' do
      expect(TypeFactory.default().class()).to eq(PDefaultType)
    end

    it 'range(to, from) returns PIntegerType' do
      t = TypeFactory.range(1,2)
      expect(t.class()).to eq(PIntegerType)
      expect(t.from).to eq(1)
      expect(t.to).to eq(2)
    end

    it 'range(default, default) returns PIntegerType' do
      t = TypeFactory.range(:default,:default)
      expect(t.class()).to eq(PIntegerType)
      expect(t.from).to eq(nil)
      expect(t.to).to eq(nil)
    end

    it 'float_range(to, from) returns PFloatType' do
      t = TypeFactory.float_range(1.0, 2.0)
      expect(t.class()).to eq(PFloatType)
      expect(t.from).to eq(1.0)
      expect(t.to).to eq(2.0)
    end

    it 'float_range(default, default) returns PFloatType' do
      t = TypeFactory.float_range(:default, :default)
      expect(t.class()).to eq(PFloatType)
      expect(t.from).to eq(nil)
      expect(t.to).to eq(nil)
    end

    it 'resource() creates a generic PResourceType' do
      pr = TypeFactory.resource()
      expect(pr.class()).to eq(PResourceType)
      expect(pr.type_name).to eq(nil)
    end

    it 'resource(x) creates a PResourceType[x]' do
      pr = TypeFactory.resource('x')
      expect(pr.class()).to eq(PResourceType)
      expect(pr.type_name).to eq('X')
    end

    it 'host_class() creates a generic PHostClassType' do
      hc = TypeFactory.host_class()
      expect(hc.class()).to eq(PHostClassType)
      expect(hc.class_name).to eq(nil)
    end

    it 'host_class(x) creates a PHostClassType[x]' do
      hc = TypeFactory.host_class('x')
      expect(hc.class()).to eq(PHostClassType)
      expect(hc.class_name).to eq('x')
    end

    it 'host_class(::x) creates a PHostClassType[x]' do
      hc = TypeFactory.host_class('::x')
      expect(hc.class()).to eq(PHostClassType)
      expect(hc.class_name).to eq('x')
    end

    it 'array_of(fixnum) returns PArrayType[PIntegerType]' do
      at = TypeFactory.array_of(1)
      expect(at.class()).to eq(PArrayType)
      expect(at.element_type.class).to eq(PIntegerType)
    end

    it 'array_of(PIntegerType) returns PArrayType[PIntegerType]' do
      at = TypeFactory.array_of(PIntegerType::DEFAULT)
      expect(at.class()).to eq(PArrayType)
      expect(at.element_type.class).to eq(PIntegerType)
    end

    it 'array_of_data returns PArrayType[PDataType]' do
      at = TypeFactory.array_of_data
      expect(at.class()).to eq(PArrayType)
      expect(at.element_type.class).to eq(PDataType)
    end

    it 'hash_of_data returns PHashType[PScalarType,PDataType]' do
      ht = TypeFactory.hash_of_data
      expect(ht.class()).to eq(PHashType)
      expect(ht.key_type.class).to eq(PScalarType)
      expect(ht.element_type.class).to eq(PDataType)
    end

    it 'ruby(1) returns PRuntimeType[ruby, \'Fixnum\']' do
      ht = TypeFactory.ruby(1)
      expect(ht.class()).to eq(PRuntimeType)
      expect(ht.runtime).to eq(:ruby)
      expect(ht.runtime_type_name).to eq('Fixnum')
    end

    it 'a size constrained collection can be created from array' do
      t = TypeFactory.array_of(TypeFactory.data, TypeFactory.range(1,2))
      expect(t.size_type.class).to eq(PIntegerType)
      expect(t.size_type.from).to eq(1)
      expect(t.size_type.to).to eq(2)
    end

    it 'a size constrained collection can be created from hash' do
      t = TypeFactory.hash_of(TypeFactory.scalar, TypeFactory.data, TypeFactory.range(1,2))
      expect(t.size_type.class).to eq(PIntegerType)
      expect(t.size_type.from).to eq(1)
      expect(t.size_type.to).to eq(2)
    end

    it 'a typed empty array, the resulting array erases the type' do
      t = Puppet::Pops::Types::TypeFactory.array_of(Puppet::Pops::Types::TypeFactory.data, Puppet::Pops::Types::TypeFactory.range(0,0))
      expect(t.size_type.class).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.size_type.from).to eq(0)
      expect(t.size_type.to).to eq(0)
      expect(t.element_type).to eq(Puppet::Pops::Types::PUnitType::DEFAULT)
    end

    it 'a typed empty hash, the resulting hash erases the key and value type' do
      t = Puppet::Pops::Types::TypeFactory.hash_of(Puppet::Pops::Types::TypeFactory.scalar, Puppet::Pops::Types::TypeFactory.data, Puppet::Pops::Types::TypeFactory.range(0,0))
      expect(t.size_type.class).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.size_type.from).to eq(0)
      expect(t.size_type.to).to eq(0)
      expect(t.key_type).to eq(Puppet::Pops::Types::PUnitType::DEFAULT)
      expect(t.element_type).to eq(Puppet::Pops::Types::PUnitType::DEFAULT)
    end

    context 'callable types' do
      it 'the callable methods produces a Callable' do
        t = TypeFactory.callable()
        expect(t.class).to be(PCallableType)
        expect(t.param_types.class).to be(PTupleType)
        expect(t.param_types.types).to be_empty
        expect(t.block_type).to be_nil
      end

      it 'callable method with types produces the corresponding Tuple for parameters and generated names' do
        tf = TypeFactory
        t = tf.callable(tf.integer, tf.string)
        expect(t.class).to be(PCallableType)
        expect(t.param_types.class).to be(PTupleType)
        expect(t.param_types.types).to eql([tf.integer, tf.string])
        expect(t.block_type).to be_nil
      end

      it 'callable accepts min range to be given' do
        tf = TypeFactory
        t = tf.callable(tf.integer, tf.string, 1)
        expect(t.class).to be(PCallableType)
        expect(t.param_types.class).to be(PTupleType)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to be_nil
      end

      it 'callable accepts max range to be given' do
        tf = TypeFactory
        t = tf.callable(tf.integer, tf.string, 1, 3)
        expect(t.class).to be(PCallableType)
        expect(t.param_types.class).to be(PTupleType)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to eql(3)
      end

      it 'callable accepts max range to be given as :default' do
        tf = TypeFactory
        t = tf.callable(tf.integer, tf.string, 1, :default)
        expect(t.class).to be(PCallableType)
        expect(t.param_types.class).to be(PTupleType)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to be_nil
      end

      it 'the all_callables method produces a Callable matching any Callable' do
        t = TypeFactory.all_callables()
        expect(t.class).to be(PCallableType)
        expect(t.param_types).to be_nil
        expect(t.block_type).to be_nil
      end

      it 'with block are created by placing a Callable last' do
        block_t = TypeFactory.callable(String)
        t = TypeFactory.callable(String, block_t)
        expect(t.block_type).to be(block_t)
      end

      it 'min size constraint can be used with a block last' do
        block_t = TypeFactory.callable(String)
        t = TypeFactory.callable(String, 1, block_t)
        expect(t.block_type).to be(block_t)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to be_nil
      end

      it 'min, max size constraint can be used with a block last' do
        block_t = TypeFactory.callable(String)
        t = TypeFactory.callable(String, 1, 3, block_t)
        expect(t.block_type).to be(block_t)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to eql(3)
      end

      it 'the with_block methods decorates a Callable with a block_type' do
        t = TypeFactory.callable
        t2 = TypeFactory.callable(t)
        block_t = t2.block_type
        # given t is returned after mutation
        expect(block_t).to be(t)
        expect(block_t.class).to be(PCallableType)
        expect(block_t.param_types.class).to be(PTupleType)
        expect(block_t.param_types.types).to be_empty
        expect(block_t.block_type).to be_nil
      end

      it 'the with_optional_block methods decorates a Callable with an optional block_type' do
        b = TypeFactory.callable
        t = TypeFactory.optional(b)
        t2 = TypeFactory.callable(t)
        opt_t = t2.block_type
        expect(opt_t.class).to be(POptionalType)
        block_t = opt_t.optional_type
        # given t is returned after mutation
        expect(opt_t).to be(t)
        expect(block_t).to be(b)
        expect(block_t.class).to be(PCallableType)
        expect(block_t.param_types.class).to be(PTupleType)
        expect(block_t.param_types.types).to be_empty
        expect(block_t.block_type).to be_nil
      end
    end
  end
end
end
end
