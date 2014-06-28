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

    it 'default() returns PDefaultType' do
      Puppet::Pops::Types::TypeFactory.default().class().should == Puppet::Pops::Types::PDefaultType
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

    it 'host_class(::x) creates a PHostClassType[x]' do
      hc = Puppet::Pops::Types::TypeFactory.host_class('::x')
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

    it 'ruby(1) returns PRuntimeType[ruby, \'Fixnum\']' do
      ht = Puppet::Pops::Types::TypeFactory.ruby(1)
      ht.class().should == Puppet::Pops::Types::PRuntimeType
      ht.runtime.should == :ruby
      ht.runtime_type_name.should == 'Fixnum'
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
        t = Puppet::Pops::Types::TypeFactory.callable()
        t2 = Puppet::Pops::Types::TypeFactory.with_block(t)
        block_t = t2.block_type
        # given t is returned after mutation
        expect(t2).to be(t)
        expect(block_t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(block_t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(block_t.param_types.types).to be_empty
        expect(block_t.block_type).to be_nil
      end

      it 'the with_optional_block methods decorates a Callable with an optional block_type' do
        t = Puppet::Pops::Types::TypeFactory.callable()
        t2 = Puppet::Pops::Types::TypeFactory.with_optional_block(t)
        opt_t = t2.block_type
        expect(opt_t.class).to be(Puppet::Pops::Types::POptionalType)
        block_t = opt_t.optional_type
        # given t is returned after mutation
        expect(t2).to be(t)
        expect(block_t.class).to be(Puppet::Pops::Types::PCallableType)
        expect(block_t.param_types.class).to be(Puppet::Pops::Types::PTupleType)
        expect(block_t.param_types.types).to be_empty
        expect(block_t.block_type).to be_nil
      end
    end
  end
end
