require 'spec_helper'
require 'puppet/pops'

describe 'The type calculator' do
  let(:calculator) {  Puppet::Pops::Types::TypeCalculator.new() }

  context 'when inferring ruby' do

    it 'fixnum translates to PIntegerType' do
      calculator.infer(1).class.should == Puppet::Pops::Types::PIntegerType
    end

    it 'large fixnum (or bignum depending on architecture) translates to PIntegerType' do
      calculator.infer(2**33).class.should == Puppet::Pops::Types::PIntegerType
    end

    it 'float translates to PFloatType' do
      calculator.infer(1.3).class.should == Puppet::Pops::Types::PFloatType
    end

    it 'string translates to PStringType' do
      calculator.infer('foo').class.should == Puppet::Pops::Types::PStringType
    end

    it 'boolean true translates to PBooleanType' do
      calculator.infer(true).class.should == Puppet::Pops::Types::PBooleanType
    end

    it 'boolean false translates to PBooleanType' do
      calculator.infer(false).class.should == Puppet::Pops::Types::PBooleanType
    end

    it 'regexp translates to PPatternType' do
      calculator.infer(/^a regular exception$/).class.should == Puppet::Pops::Types::PPatternType
    end

    it 'nil translates to PNilType' do
      calculator.infer(nil).class.should == Puppet::Pops::Types::PNilType
    end

    it 'an instance of class Foo translates to PRubyType[Foo]' do
      class Foo
      end

      t = calculator.infer(Foo.new)
      t.class.should == Puppet::Pops::Types::PRubyType
      t.ruby_class.should == 'Foo'
    end

    context 'array' do
      it 'translates to PArrayType' do
        calculator.infer([1,2]).class.should == Puppet::Pops::Types::PArrayType
      end

      it 'with fixnum values translates to PArrayType[PIntegerType]' do
        calculator.infer([1,2]).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end

      it 'with 32 and 64 bit integer values translates to PArrayType[PIntegerType]' do
        calculator.infer([1,2**33]).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end

      it 'with fixnum and float values translates to PArrayType[PNumericType]' do
        calculator.infer([1,2.0]).element_type.class.should == Puppet::Pops::Types::PNumericType
      end

      it 'with fixnum and string values translates to PArrayType[PLiteralType]' do
        calculator.infer([1,'two']).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with float and string values translates to PArrayType[PLiteralType]' do
        calculator.infer([1.0,'two']).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with fixnum, float, and string values translates to PArrayType[PLiteralType]' do
        calculator.infer([1, 2.0,'two']).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with fixnum and regexp values translates to PArrayType[PLiteralType]' do
        calculator.infer([1, /two/]).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with string and regexp values translates to PArrayType[PLiteralType]' do
        calculator.infer(['one', /two/]).element_type.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with string and symbol values translates to PArrayType[PObjectType]' do
        calculator.infer(['one', :two]).element_type.class.should == Puppet::Pops::Types::PObjectType
      end

      it 'with fixnum and nil values translates to PArrayType[PIntegerType]' do
        calculator.infer([1, nil]).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end

      it 'with arrays of string values translates to PArrayType[PArrayType[PStringType]]' do
        et = calculator.infer([['first' 'array'], ['second','array']])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PStringType
      end

      it 'with array of string values and array of fixnums translates to PArrayType[PArrayType[PLiteralType]]' do
        et = calculator.infer([['first' 'array'], [1,2]])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PLiteralType
      end

      it 'with hashes of string values translates to PArrayType[PHashType[PStringType]]' do
        et = calculator.infer([{:first => 'first', :second => 'second' }, {:first => 'first', :second => 'second' }])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PHashType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PStringType
      end

      it 'with hash of string values and hash of fixnums translates to PArrayType[PHashType[PLiteralType]]' do
        et = calculator.infer([{:first => 'first', :second => 'second' }, {:first => 1, :second => 2 }])
        et.class.should == Puppet::Pops::Types::PArrayType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PHashType
        et = et.element_type
        et.class.should == Puppet::Pops::Types::PLiteralType
      end
    end

    context 'hash' do
      it 'translates to PHashType' do
        calculator.infer({:first => 1, :second => 2}).class.should == Puppet::Pops::Types::PHashType
      end

      it 'with symbolic keys translates to PHashType[PRubyType[Symbol],value]' do
        k = calculator.infer({:first => 1, :second => 2}).key_type
        k.class.should == Puppet::Pops::Types::PRubyType
        k.ruby_class.should == 'Symbol'
      end

      it 'with string keys translates to PHashType[PStringType,value]' do
        calculator.infer({'first' => 1, 'second' => 2}).key_type.class.should == Puppet::Pops::Types::PStringType
      end

      it 'with fixnum values translates to PHashType[key,PIntegerType]' do
        calculator.infer({:first => 1, :second => 2}).element_type.class.should == Puppet::Pops::Types::PIntegerType
      end
    end
  end

  # Deal with cases not covered by infer computing common type
  context 'when computing common type' do
    it 'computes given resource type commonality' do
      r1 = Puppet::Pops::Types::PResourceType.new()
      r1.type_name = 'File'
      r2 = Puppet::Pops::Types::PResourceType.new()
      r2.type_name = 'File'
      calculator.string(calculator.common_type(r1, r2)).should == "File"

      r2 = Puppet::Pops::Types::PResourceType.new()
      r2.type_name = 'File'
      r2.title = '/tmp/foo'
      calculator.string(calculator.common_type(r1, r2)).should == "File"

      r1 = Puppet::Pops::Types::PResourceType.new()
      r1.type_name = 'File'
      r1.title = '/tmp/foo'
      calculator.string(calculator.common_type(r1, r2)).should == "File['/tmp/foo']"

      r1 = Puppet::Pops::Types::PResourceType.new()
      r1.type_name = 'File'
      r1.title = '/tmp/bar'
      calculator.string(calculator.common_type(r1, r2)).should == "File"

      r2 = Puppet::Pops::Types::PResourceType.new()
      r2.type_name = 'Package'
      r2.title = 'apache'
      calculator.string(calculator.common_type(r1, r2)).should == "Resource"
    end

    it 'computes given hostclass type commonality' do
      r1 = Puppet::Pops::Types::PHostClassType.new()
      r1.class_name = 'foo'
      r2 = Puppet::Pops::Types::PHostClassType.new()
      r2.class_name = 'foo'
      calculator.string(calculator.common_type(r1, r2)).should == "Class[foo]"

      r2 = Puppet::Pops::Types::PHostClassType.new()
      r2.class_name = 'bar'
      calculator.string(calculator.common_type(r1, r2)).should == "Class"

      r2 = Puppet::Pops::Types::PHostClassType.new()
      calculator.string(calculator.common_type(r1, r2)).should == "Class"

      r1 = Puppet::Pops::Types::PHostClassType.new()
      calculator.string(calculator.common_type(r1, r2)).should == "Class"
    end
  end

  context 'when testing if x is assignable to y' do
    it 'should allow all object types to PObjectType' do
      t = Puppet::Pops::Types::PObjectType.new()
      calculator.assignable?(t, t).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PNilType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PDataType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PLiteralType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PStringType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PNumericType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PIntegerType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PFloatType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PPatternType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PBooleanType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PCollectionType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PArrayType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PHashType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PRubyType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PHostClassType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PResourceType.new()).should() == true
    end

    it 'should reject PObjectType to less generic types' do
      t = Puppet::Pops::Types::PObjectType.new()
      calculator.assignable?(Puppet::Pops::Types::PDataType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PLiteralType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PStringType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PNumericType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PFloatType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PPatternType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PBooleanType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PCollectionType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PArrayType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PHashType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PRubyType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PHostClassType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PResourceType.new(), t).should() == false
    end

    it 'should allow all data types, array, and hash to PDataType' do
      t = Puppet::Pops::Types::PDataType.new()
      calculator.assignable?(t, t).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PLiteralType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PStringType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PNumericType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PIntegerType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PFloatType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PPatternType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PBooleanType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PArrayType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PHashType.new()).should() == true
    end

    it 'should reject PDataType to less generic data types' do
      t = Puppet::Pops::Types::PDataType.new()
      calculator.assignable?(Puppet::Pops::Types::PLiteralType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PStringType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PNumericType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PFloatType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PPatternType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PBooleanType.new(), t).should() == false
    end

    it 'should reject PDataType to non data types' do
      t = Puppet::Pops::Types::PDataType.new()
      calculator.assignable?(Puppet::Pops::Types::PCollectionType.new(),t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PArrayType.new(),t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PHashType.new(),t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PRubyType.new(), t).should() == false
    end

    it 'should allow all literal types to PLiteralType' do
      t = Puppet::Pops::Types::PLiteralType.new()
      calculator.assignable?(t, t).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PStringType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PNumericType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PIntegerType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PFloatType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PPatternType.new()).should() == true
      calculator.assignable?(t,Puppet::Pops::Types::PBooleanType.new()).should() == true
    end

    it 'should reject PLiteralType to less generic literal types' do
      t = Puppet::Pops::Types::PLiteralType.new()
      calculator.assignable?(Puppet::Pops::Types::PStringType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PNumericType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PFloatType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PPatternType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PBooleanType.new(), t).should() == false
    end

    it 'should reject PLiteralType to non literal types' do
      t = Puppet::Pops::Types::PLiteralType.new()
      calculator.assignable?(Puppet::Pops::Types::PCollectionType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PArrayType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PHashType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PRubyType.new(), t).should() == false
    end

    it 'should allow all numeric types to PNumericType' do
      t = Puppet::Pops::Types::PNumericType.new()
      calculator.assignable?(t, t).should() == true
      calculator.assignable?(t, Puppet::Pops::Types::PIntegerType.new()).should() == true
      calculator.assignable?(t, Puppet::Pops::Types::PFloatType.new()).should() == true
    end

    it 'should reject PNumericType to less generic numeric types' do
      t = Puppet::Pops::Types::PNumericType.new()
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PFloatType.new(), t).should() == false
    end

    it 'should reject PNumericType to non numeric types' do
      t = Puppet::Pops::Types::PNumericType.new()
      calculator.assignable?(Puppet::Pops::Types::PStringType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PPatternType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PBooleanType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PCollectionType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PArrayType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PHashType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PRubyType.new(), t).should() == false
    end

    it 'should allow all collection types to PCollectionType' do
      t = Puppet::Pops::Types::PCollectionType.new()
      calculator.assignable?(t, t).should() == true
      calculator.assignable?(t, Puppet::Pops::Types::PArrayType.new()).should() == true
      calculator.assignable?(t, Puppet::Pops::Types::PHashType.new()).should() == true
    end

    it 'should reject PCollectionType to less generic collection types' do
      t = Puppet::Pops::Types::PCollectionType.new()
      calculator.assignable?(Puppet::Pops::Types::PArrayType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PHashType.new(), t).should() == false
    end

    it 'should reject PCollectionType to non collection types' do
      t = Puppet::Pops::Types::PCollectionType.new()
      calculator.assignable?(Puppet::Pops::Types::PDataType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PLiteralType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PStringType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PNumericType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PFloatType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PPatternType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PBooleanType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PRubyType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PHostClassType.new(), t).should() == false
      calculator.assignable?(Puppet::Pops::Types::PResourceType.new(), t).should() == false
    end

    it 'should reject PArrayType to non array type collections' do
      t = Puppet::Pops::Types::PArrayType.new()
      calculator.assignable?(Puppet::Pops::Types::PHashType.new(), t).should() == false
    end

    it 'should reject PHashType to non hash type collections' do
      t = Puppet::Pops::Types::PHashType.new()
      calculator.assignable?(Puppet::Pops::Types::PArrayType.new(), t).should() == false
    end

    it 'should recognize mapped ruby types' do 
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), Integer).should == true
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), Fixnum).should == true
      calculator.assignable?(Puppet::Pops::Types::PIntegerType.new(), Bignum).should == true
      calculator.assignable?(Puppet::Pops::Types::PFloatType.new(), Float).should == true
      calculator.assignable?(Puppet::Pops::Types::PNumericType.new(), Numeric).should == true
      calculator.assignable?(Puppet::Pops::Types::PNilType.new(), NilClass).should == true
      calculator.assignable?(Puppet::Pops::Types::PBooleanType.new(), FalseClass).should == true
      calculator.assignable?(Puppet::Pops::Types::PBooleanType.new(), TrueClass).should == true
      calculator.assignable?(Puppet::Pops::Types::PStringType.new(), String).should == true
      calculator.assignable?(Puppet::Pops::Types::PPatternType.new(), Regexp).should == true
      calculator.assignable?(Puppet::Pops::Types::TypeFactory.array_of_data(), Array).should == true
      calculator.assignable?(Puppet::Pops::Types::TypeFactory.hash_of_data(), Hash).should == true
    end

    it 'should recognize ruby type inheritance' do
      class Foo
      end

      class Bar < Foo
      end

      fooType = calculator.infer(Foo.new)
      barType = calculator.infer(Bar.new)

      calculator.assignable?(fooType, fooType).should == true
      calculator.assignable?(Foo, fooType).should == true

      calculator.assignable?(fooType, barType).should == true
      calculator.assignable?(Foo, barType).should == true

      calculator.assignable?(barType, fooType).should == false
      calculator.assignable?(Bar, fooType).should == false
    end

    it "should allow host class with same name" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      hc2 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      calculator.assignable?(hc1, hc2).should == true
    end

    it "should allow host class with name assigned to hostclass without name" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class()
      hc2 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      calculator.assignable?(hc1, hc2).should == true
    end

    it "should reject host classes with different names" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      hc2 = Puppet::Pops::Types::TypeFactory.host_class('another_name')
      calculator.assignable?(hc1, hc2).should == false
    end

    it "should reject host classes without name assigned to host class with name" do
      hc1 = Puppet::Pops::Types::TypeFactory.host_class('the_name')
      hc2 = Puppet::Pops::Types::TypeFactory.host_class()
      calculator.assignable?(hc1, hc2).should == false
    end

    it "should allow resource with same type_name and title" do
      r1 = Puppet::Pops::Types::TypeFactory.resource('file', 'foo')
      r2 = Puppet::Pops::Types::TypeFactory.resource('file', 'foo')
      calculator.assignable?(r1, r2).should == true
    end

    it "should allow more specific resource assignment" do
      r1 = Puppet::Pops::Types::TypeFactory.resource()
      r2 = Puppet::Pops::Types::TypeFactory.resource('file')
      calculator.assignable?(r1, r2).should == true
      r2 = Puppet::Pops::Types::TypeFactory.resource('file', '/tmp/foo')
      calculator.assignable?(r1, r2).should == true
      r1 = Puppet::Pops::Types::TypeFactory.resource('file')
      calculator.assignable?(r1, r2).should == true
    end

    it "should reject less specific resource assignment" do
      r1 = Puppet::Pops::Types::TypeFactory.resource('file', '/tmp/foo')
      r2 = Puppet::Pops::Types::TypeFactory.resource('file')
      calculator.assignable?(r1, r2).should == false
      r2 = Puppet::Pops::Types::TypeFactory.resource()
      calculator.assignable?(r1, r2).should == false
    end

  end

  context 'when testing if x is instance of type t' do
    it 'should consider fixnum instanceof PIntegerType' do
      calculator.instance?(Puppet::Pops::Types::PIntegerType.new(), 1)
    end

    it 'should consider fixnum instanceof Fixnum' do
      calculator.instance?(Fixnum, 1)
    end
  end

  context 'when converting a ruby class' do
    it 'should yield \'PIntegerType\' for Integer, Fixnum, and Bignum' do
      [Integer,Fixnum,Bignum].each do |c|
        calculator.type(c).class.should == Puppet::Pops::Types::PIntegerType
      end
    end

    it 'should yield \'PFloatType\' for Float' do
      calculator.type(Float).class.should == Puppet::Pops::Types::PFloatType
    end

    it 'should yield \'PBooleanType\' for FalseClass and TrueClass' do
      [FalseClass,TrueClass].each do |c|
        calculator.type(c).class.should == Puppet::Pops::Types::PBooleanType
      end
    end

    it 'should yield \'PNilType\' for NilClass' do
      calculator.type(NilClass).class.should == Puppet::Pops::Types::PNilType
    end

    it 'should yield \'PStringType\' for String' do
      calculator.type(String).class.should == Puppet::Pops::Types::PStringType
    end

    it 'should yield \'PPatternType\' for Regexp' do
      calculator.type(Regexp).class.should == Puppet::Pops::Types::PPatternType
    end

    it 'should yield \'PArrayType[PDataType]\' for Array' do
      t = calculator.type(Array)
      t.class.should == Puppet::Pops::Types::PArrayType
      t.element_type.class.should == Puppet::Pops::Types::PDataType
    end

    it 'should yield \'PHashType[PLiteralType,PDataType]\' for Hash' do
      t = calculator.type(Hash)
      t.class.should == Puppet::Pops::Types::PHashType
      t.key_type.class.should == Puppet::Pops::Types::PLiteralType
      t.element_type.class.should == Puppet::Pops::Types::PDataType
    end
  end

  context 'when representing the type as string' do
    it 'should yield \'Type\' for PType' do
      calculator.string(Puppet::Pops::Types::PType.new()).should == 'Type'
    end

    it 'should yield \'Object\' for PObjectType' do
      calculator.string(Puppet::Pops::Types::PObjectType.new()).should == 'Object'
    end

    it 'should yield \'Literal\' for PLiteralType' do
      calculator.string(Puppet::Pops::Types::PLiteralType.new()).should == 'Literal'
    end

    it 'should yield \'Boolean\' for PBooleanType' do
      calculator.string(Puppet::Pops::Types::PBooleanType.new()).should == 'Boolean'
    end

    it 'should yield \'Data\' for PDataType' do
      calculator.string(Puppet::Pops::Types::PDataType.new()).should == 'Data'
    end

    it 'should yield \'Numeric\' for PNumericType' do
      calculator.string(Puppet::Pops::Types::PNumericType.new()).should == 'Numeric'
    end

    it 'should yield \'Integer\' for PIntegerType' do
      calculator.string(Puppet::Pops::Types::PIntegerType.new()).should == 'Integer'
    end

    it 'should yield \'Float\' for PFloatType' do
      calculator.string(Puppet::Pops::Types::PFloatType.new()).should == 'Float'
    end

    it 'should yield \'Pattern\' for PPatternType' do
      calculator.string(Puppet::Pops::Types::PPatternType.new()).should == 'Pattern'
    end

    it 'should yield \'String\' for PStringType' do
      calculator.string(Puppet::Pops::Types::PStringType.new()).should == 'String'
    end

    it 'should yield \'Array[Integer]\' for PArrayType[PIntegerType]' do
      t = Puppet::Pops::Types::PArrayType.new()
      t.element_type = Puppet::Pops::Types::PIntegerType.new()
      calculator.string(t).should == 'Array[Integer]'
    end

    it 'should yield \'Hash[String, Integer]\' for PHashType[PStringType, PIntegerType]' do
      t = Puppet::Pops::Types::PHashType.new()
      t.key_type = Puppet::Pops::Types::PStringType.new()
      t.element_type = Puppet::Pops::Types::PIntegerType.new()
      calculator.string(t).should == 'Hash[String, Integer]'
    end

    it "should yield 'Class' for a PHostClassType" do
      t = Puppet::Pops::Types::PHostClassType.new()
      calculator.string(t).should == 'Class'
    end

    it "should yield 'Class[x]' for a PHostClassType[x]" do
      t = Puppet::Pops::Types::PHostClassType.new()
      t.class_name = 'x'
      calculator.string(t).should == 'Class[x]'
    end

    it "should yield 'Resource' for a PResourceType" do
      t = Puppet::Pops::Types::PResourceType.new()
      calculator.string(t).should == 'Resource'
    end

    it 'should yield \'File\' for a PResourceType[\'File\']' do
      t = Puppet::Pops::Types::PResourceType.new()
      t.type_name = 'File'
      calculator.string(t).should == 'File'
    end

    it "should yield 'File['/tmp/foo']' for a PResourceType['File', '/tmp/foo']" do
      t = Puppet::Pops::Types::PResourceType.new()
      t.type_name = 'File'
      t.title = '/tmp/foo'
      calculator.string(t).should == "File['/tmp/foo']"
    end
  end

  context 'when processing meta type' do
    it 'should infer PType as the type of all other types' do
      ptype = Puppet::Pops::Types::PType
      calculator.infer(Puppet::Pops::Types::PNilType.new()       ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PDataType.new()      ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PLiteralType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PStringType.new()    ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PNumericType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PIntegerType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PFloatType.new()     ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PPatternType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PBooleanType.new()   ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PCollectionType.new()).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PArrayType.new()     ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PHashType.new()      ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PRubyType.new()      ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PHostClassType.new() ).is_a?(ptype).should() == true
      calculator.infer(Puppet::Pops::Types::PResourceType.new()  ).is_a?(ptype).should() == true
      calculator.string(calculator.infer(Puppet::Pops::Types::PIntegerType.new())).should == "Type[Integer]"
    end

    it 'should infer PType as the type of all other types' do
      ptype = Puppet::Pops::Types::PType
      calculator.string(calculator.infer(Puppet::Pops::Types::PNilType.new()       )).should == "Type[Undef]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PDataType.new()      )).should == "Type[Data]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PLiteralType.new()   )).should == "Type[Literal]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PStringType.new()    )).should == "Type[String]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PNumericType.new()   )).should == "Type[Numeric]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PIntegerType.new()   )).should == "Type[Integer]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PFloatType.new()     )).should == "Type[Float]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PPatternType.new()   )).should == "Type[Pattern]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PBooleanType.new()   )).should == "Type[Boolean]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PCollectionType.new())).should == "Type[Collection]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PArrayType.new()     )).should == "Type[Array[?]]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PHashType.new()      )).should == "Type[Hash[?, ?]]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PRubyType.new()      )).should == "Type[Ruby[?]]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PHostClassType.new() )).should == "Type[Class]"
      calculator.string(calculator.infer(Puppet::Pops::Types::PResourceType.new()  )).should == "Type[Resource]"
    end

    it "computes the common type of PType's type parameter" do
      int_t    = Puppet::Pops::Types::PIntegerType.new()
      string_t = Puppet::Pops::Types::PStringType.new()
      calculator.string(calculator.infer([int_t])).should == "Array[Type[Integer]]"
      calculator.string(calculator.infer([int_t, string_t])).should == "Array[Type[Literal]]"
    end

    it 'should infer PType as the type of ruby classes' do
      class Foo
      end
      [Object, Numeric, Integer, Fixnum, Bignum, Float, String, Regexp, Array, Hash, Foo].each do |c|
        calculator.infer(c).is_a?(Puppet::Pops::Types::PType).should() == true
      end
    end

    it 'should infer PType as the type of PType (meta regression short-circuit)' do
      calculator.infer(Puppet::Pops::Types::PType.new()).is_a?(Puppet::Pops::Types::PType).should() == true
    end
  end
end
