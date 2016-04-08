require 'spec_helper'
require 'puppet/pops'

describe 'The type factory' do
  context 'when creating' do
    it 'integer() returns PIntegerType' do
      expect(Puppet::Pops::Types::TypeFactory.integer().class()).to eq(Puppet::Pops::Types::PIntegerType)
    end

    it 'float() returns PFloatType' do
      expect(Puppet::Pops::Types::TypeFactory.float().class()).to eq(Puppet::Pops::Types::PFloatType)
    end

    it 'string() returns PStringType' do
      expect(Puppet::Pops::Types::TypeFactory.string().class()).to eq(Puppet::Pops::Types::PStringType)
    end

    it 'boolean() returns PBooleanType' do
      expect(Puppet::Pops::Types::TypeFactory.boolean().class()).to eq(Puppet::Pops::Types::PBooleanType)
    end

    it 'pattern() returns PPatternType' do
      expect(Puppet::Pops::Types::TypeFactory.pattern().class()).to eq(Puppet::Pops::Types::PPatternType)
    end

    it 'regexp() returns PRegexpType' do
      expect(Puppet::Pops::Types::TypeFactory.regexp().class()).to eq(Puppet::Pops::Types::PRegexpType)
    end

    it 'enum() returns PEnumType' do
      expect(Puppet::Pops::Types::TypeFactory.enum().class()).to eq(Puppet::Pops::Types::PEnumType)
    end

    it 'variant() returns PVariantType' do
      expect(Puppet::Pops::Types::TypeFactory.variant().class()).to eq(Puppet::Pops::Types::PVariantType)
    end

    it 'scalar() returns PScalarType' do
      expect(Puppet::Pops::Types::TypeFactory.scalar().class()).to eq(Puppet::Pops::Types::PScalarType)
    end

    it 'data() returns PDataType' do
      expect(Puppet::Pops::Types::TypeFactory.data().class()).to eq(Puppet::Pops::Types::PDataType)
    end

    it 'optional() returns POptionalType' do
      expect(Puppet::Pops::Types::TypeFactory.optional().class()).to eq(Puppet::Pops::Types::POptionalType)
    end

    it 'collection() returns PCollectionType' do
      expect(Puppet::Pops::Types::TypeFactory.collection().class()).to eq(Puppet::Pops::Types::PCollectionType)
    end

    it 'catalog_entry() returns PCatalogEntryType' do
      expect(Puppet::Pops::Types::TypeFactory.catalog_entry().class()).to eq(Puppet::Pops::Types::PCatalogEntryType)
    end

    it 'struct() returns PStructType' do
      expect(Puppet::Pops::Types::TypeFactory.struct().class()).to eq(Puppet::Pops::Types::PStructType)
    end

    it 'tuple() returns PTupleType' do
      expect(Puppet::Pops::Types::TypeFactory.tuple.class()).to eq(Puppet::Pops::Types::PTupleType)
    end

    it 'undef() returns PUndefType' do
      expect(Puppet::Pops::Types::TypeFactory.undef().class()).to eq(Puppet::Pops::Types::PUndefType)
    end

    it 'default() returns PDefaultType' do
      expect(Puppet::Pops::Types::TypeFactory.default().class()).to eq(Puppet::Pops::Types::PDefaultType)
    end

    it 'range(to, from) returns PIntegerType' do
      t = Puppet::Pops::Types::TypeFactory.range(1,2)
      expect(t.class()).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.from).to eq(1)
      expect(t.to).to eq(2)
    end

    it 'range(default, default) returns PIntegerType' do
      t = Puppet::Pops::Types::TypeFactory.range(:default,:default)
      expect(t.class()).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.from).to eq(nil)
      expect(t.to).to eq(nil)
    end

    it 'float_range(to, from) returns PFloatType' do
      t = Puppet::Pops::Types::TypeFactory.float_range(1.0, 2.0)
      expect(t.class()).to eq(Puppet::Pops::Types::PFloatType)
      expect(t.from).to eq(1.0)
      expect(t.to).to eq(2.0)
    end

    it 'float_range(default, default) returns PFloatType' do
      t = Puppet::Pops::Types::TypeFactory.float_range(:default, :default)
      expect(t.class()).to eq(Puppet::Pops::Types::PFloatType)
      expect(t.from).to eq(nil)
      expect(t.to).to eq(nil)
    end

    it 'resource() creates a generic PResourceType' do
      pr = Puppet::Pops::Types::TypeFactory.resource()
      expect(pr.class()).to eq(Puppet::Pops::Types::PResourceType)
      expect(pr.type_name).to eq(nil)
    end

    it 'resource(x) creates a PResourceType[x]' do
      pr = Puppet::Pops::Types::TypeFactory.resource('x')
      expect(pr.class()).to eq(Puppet::Pops::Types::PResourceType)
      expect(pr.type_name).to eq('x')
    end

    it 'host_class() creates a generic PHostClassType' do
      hc = Puppet::Pops::Types::TypeFactory.host_class()
      expect(hc.class()).to eq(Puppet::Pops::Types::PHostClassType)
      expect(hc.class_name).to eq(nil)
    end

    it 'host_class(x) creates a PHostClassType[x]' do
      hc = Puppet::Pops::Types::TypeFactory.host_class('x')
      expect(hc.class()).to eq(Puppet::Pops::Types::PHostClassType)
      expect(hc.class_name).to eq('x')
    end

    it 'host_class(::x) creates a PHostClassType[x]' do
      hc = Puppet::Pops::Types::TypeFactory.host_class('::x')
      expect(hc.class()).to eq(Puppet::Pops::Types::PHostClassType)
      expect(hc.class_name).to eq('x')
    end

    it 'array_of(fixnum) returns PArrayType[PIntegerType]' do
      at = Puppet::Pops::Types::TypeFactory.array_of(1)
      expect(at.class()).to eq(Puppet::Pops::Types::PArrayType)
      expect(at.element_type.class).to eq(Puppet::Pops::Types::PIntegerType)
    end

    it 'array_of(PIntegerType) returns PArrayType[PIntegerType]' do
      at = Puppet::Pops::Types::TypeFactory.array_of(Puppet::Pops::Types::PIntegerType::DEFAULT)
      expect(at.class()).to eq(Puppet::Pops::Types::PArrayType)
      expect(at.element_type.class).to eq(Puppet::Pops::Types::PIntegerType)
    end

    it 'array_of_data returns PArrayType[PDataType]' do
      at = Puppet::Pops::Types::TypeFactory.array_of_data
      expect(at.class()).to eq(Puppet::Pops::Types::PArrayType)
      expect(at.element_type.class).to eq(Puppet::Pops::Types::PDataType)
    end

    it 'hash_of_data returns PHashType[PScalarType,PDataType]' do
      ht = Puppet::Pops::Types::TypeFactory.hash_of_data
      expect(ht.class()).to eq(Puppet::Pops::Types::PHashType)
      expect(ht.key_type.class).to eq(Puppet::Pops::Types::PScalarType)
      expect(ht.element_type.class).to eq(Puppet::Pops::Types::PDataType)
    end

    it 'ruby(1) returns PRuntimeType[ruby, \'Fixnum\']' do
      ht = Puppet::Pops::Types::TypeFactory.ruby(1)
      expect(ht.class()).to eq(Puppet::Pops::Types::PRuntimeType)
      expect(ht.runtime).to eq(:ruby)
      expect(ht.runtime_type_name).to eq('Fixnum')
    end

    it 'a size constrained collection can be created from array' do
      t = Puppet::Pops::Types::TypeFactory.array_of(Puppet::Pops::Types::TypeFactory.data, Puppet::Pops::Types::TypeFactory.range(1,2))
      expect(t.size_type.class).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.size_type.from).to eq(1)
      expect(t.size_type.to).to eq(2)
    end

    it 'a size constrained collection can be created from hash' do
      t = Puppet::Pops::Types::TypeFactory.hash_of(Puppet::Pops::Types::TypeFactory.scalar, Puppet::Pops::Types::TypeFactory.data, Puppet::Pops::Types::TypeFactory.range(1,2))
      expect(t.size_type.class).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.size_type.from).to eq(1)
      expect(t.size_type.to).to eq(2)
    end

    it 'it is illegal to create a typed empty array' do
      expect {
        Puppet::Pops::Types::TypeFactory.array_of(Puppet::Pops::Types::TypeFactory.data, Puppet::Pops::Types::TypeFactory.range(0,0))
      }.to raise_error(/An empty collection may not specify an element type/)
    end

    it 'it is legal to create an empty array of unit element type' do
      t = Puppet::Pops::Types::TypeFactory.array_of(Puppet::Pops::Types::PUnitType::DEFAULT, Puppet::Pops::Types::TypeFactory.range(0,0))
      expect(t.size_type.class).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.size_type.from).to eq(0)
      expect(t.size_type.to).to eq(0)
    end

    it 'it is illegal to create a typed empty hash' do
      expect {
        Puppet::Pops::Types::TypeFactory.hash_of(Puppet::Pops::Types::TypeFactory.scalar, Puppet::Pops::Types::TypeFactory.data, Puppet::Pops::Types::TypeFactory.range(0,0))
      }.to raise_error(/An empty collection may not specify an element type/)
    end

    it 'it is legal to create an empty hash where key and value types are of Unit type' do
      t = Puppet::Pops::Types::TypeFactory.hash_of(Puppet::Pops::Types::PUnitType::DEFAULT, Puppet::Pops::Types::PUnitType::DEFAULT, Puppet::Pops::Types::TypeFactory.range(0,0))
      expect(t.size_type.class).to eq(Puppet::Pops::Types::PIntegerType)
      expect(t.size_type.from).to eq(0)
      expect(t.size_type.to).to eq(0)
    end

    context 'callable types' do
      it 'the callable methods produces a Callable' do
        t = Puppet::Pops::Types::TypeFactory.callable()
        expect(t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t.param_types.types).to be_empty
        expect(t.block_type).to be_nil
      end

      it 'callable method with types produces the corresponding Tuple for parameters and generated names' do
        tf = Puppet::Pops::Types::TypeFactory
        t = tf.callable(tf.integer, tf.string)
        expect(t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t.param_types.types).to eql([tf.integer, tf.string])
        expect(t.block_type).to be_nil
      end

      it 'callable accepts min range to be given' do
        tf = Puppet::Pops::Types::TypeFactory
        t = tf.callable(tf.integer, tf.string, 1)
        expect(t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to be_nil
      end

      it 'callable accepts max range to be given' do
        tf = Puppet::Pops::Types::TypeFactory
        t = tf.callable(tf.integer, tf.string, 1, 3)
        expect(t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to eql(3)
      end

      it 'callable accepts max range to be given as :default' do
        tf = Puppet::Pops::Types::TypeFactory
        t = tf.callable(tf.integer, tf.string, 1, :default)
        expect(t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to be_nil
      end

      it 'the all_callables method produces a Callable matching any Callable' do
        t = Puppet::Pops::Types::TypeFactory.all_callables()
        expect(t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(t.param_types).to be_nil
        expect(t.block_type).to be_nil
      end

      it 'with block are created by placing a Callable last' do
        block_t = Puppet::Pops::Types::TypeFactory.callable(String)
        t = Puppet::Pops::Types::TypeFactory.callable(String, block_t)
        expect(t.block_type).to be(block_t)
      end

      it 'min size constraint can be used with a block last' do
        block_t = Puppet::Pops::Types::TypeFactory.callable(String)
        t = Puppet::Pops::Types::TypeFactory.callable(String, 1, block_t)
        expect(t.block_type).to be(block_t)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to be_nil
      end

      it 'min, max size constraint can be used with a block last' do
        block_t = Puppet::Pops::Types::TypeFactory.callable(String)
        t = Puppet::Pops::Types::TypeFactory.callable(String, 1, 3, block_t)
        expect(t.block_type).to be(block_t)
        expect(t.param_types.size_type.from).to eql(1)
        expect(t.param_types.size_type.to).to eql(3)
      end

      it 'the with_block methods decorates a Callable with a block_type' do
        t = Puppet::Pops::Types::TypeFactory.callable
        t2 = Puppet::Pops::Types::TypeFactory.callable(t)
        block_t = t2.block_type
        # given t is returned after mutation
        expect(block_t).to be(t)
        expect(block_t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(block_t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(block_t.param_types.types).to be_empty
        expect(block_t.block_type).to be_nil
      end

      it 'the with_optional_block methods decorates a Callable with an optional block_type' do
        b = Puppet::Pops::Types::TypeFactory.callable
        t = Puppet::Pops::Types::TypeFactory.optional(b)
        t2 = Puppet::Pops::Types::TypeFactory.callable(t)
        opt_t = t2.block_type
        expect(opt_t.class).to be(Puppet::Pops::Types::POptionalType)
        block_t = opt_t.optional_type
        # given t is returned after mutation
        expect(opt_t).to be(t)
        expect(block_t).to be(b)
        expect(block_t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(block_t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(block_t.param_types.types).to be_empty
        expect(block_t.block_type).to be_nil
      end
    end
  end
end
