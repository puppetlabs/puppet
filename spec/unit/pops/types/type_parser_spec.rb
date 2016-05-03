require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Types
describe TypeParser do
  extend RSpec::Matchers::DSL

  let(:parser) { TypeParser.new }
  let(:types)  { TypeFactory }
  it "rejects a puppet expression" do
    expect { parser.parse("1 + 1") }.to raise_error(Puppet::ParseError, /The expression <1 \+ 1> is not a valid type specification/)
  end

  it "rejects a empty type specification" do
    expect { parser.parse("") }.to raise_error(Puppet::ParseError, /The expression <> is not a valid type specification/)
  end

  it "rejects an invalid type simple type" do
    expect { parser.parse("notAType") }.to raise_error(Puppet::ParseError, /The expression <notAType> is not a valid type specification/)
  end

  it "rejects an unknown parameterized type" do
    expect { parser.parse("notAType[Integer]") }.to raise_error(Puppet::ParseError,
      /The expression <notAType\[Integer\]> is not a valid type specification/)
  end

  it "rejects an unknown type parameter" do
    expect { parser.parse("Array[notAType]") }.to raise_error(Puppet::ParseError,
      /The expression <Array\[notAType\]> is not a valid type specification/)
  end

  [
    'Any', 'Data', 'CatalogEntry', 'Boolean', 'Scalar', 'Undef', 'Numeric', 'Default'
  ].each do |name|
    it "does not support parameterizing unparameterized type <#{name}>" do
      expect { parser.parse("#{name}[Integer]") }.to raise_unparameterized_error_for(name)
    end
  end

  it "parses a simple, unparameterized type into the type object" do
    expect(the_type_parsed_from(types.any)).to be_the_type(types.any)
    expect(the_type_parsed_from(types.integer)).to be_the_type(types.integer)
    expect(the_type_parsed_from(types.float)).to be_the_type(types.float)
    expect(the_type_parsed_from(types.string)).to be_the_type(types.string)
    expect(the_type_parsed_from(types.boolean)).to be_the_type(types.boolean)
    expect(the_type_parsed_from(types.pattern)).to be_the_type(types.pattern)
    expect(the_type_parsed_from(types.data)).to be_the_type(types.data)
    expect(the_type_parsed_from(types.catalog_entry)).to be_the_type(types.catalog_entry)
    expect(the_type_parsed_from(types.collection)).to be_the_type(types.collection)
    expect(the_type_parsed_from(types.tuple)).to be_the_type(types.tuple)
    expect(the_type_parsed_from(types.struct)).to be_the_type(types.struct)
    expect(the_type_parsed_from(types.optional)).to be_the_type(types.optional)
    expect(the_type_parsed_from(types.default)).to be_the_type(types.default)
  end

  it "interprets an unparameterized Array as an Array of Data" do
    expect(parser.parse("Array")).to be_the_type(types.array_of_data)
  end

  it "interprets an unparameterized Hash as a Hash of Scalar to Data" do
    expect(parser.parse("Hash")).to be_the_type(types.hash_of_data)
  end

  it "interprets a parameterized Array[0, 0] as an empty hash with no key and value type" do
    expect(parser.parse("Array[0, 0]")).to be_the_type(types.array_of(types.default, types.range(0, 0)))
  end

  it "interprets a parameterized Hash[0, 0] as an empty hash with no key and value type" do
    expect(parser.parse("Hash[0, 0]")).to be_the_type(types.hash_of(types.default, types.default, types.range(0, 0)))
  end

  it "interprets a parameterized Hash[t] as a Hash of Scalar to t" do
    expect(parser.parse("Hash[Scalar, Integer]")).to be_the_type(types.hash_of(types.integer))
  end

  it 'interprets an Integer with one parameter to have unbounded upper range' do
    expect(parser.parse('Integer[0]')).to eq(parser.parse('Integer[0,default]'))
  end

  it 'interprets a Float with one parameter to have unbounded upper range' do
    expect(parser.parse('Float[0]')).to eq(parser.parse('Float[0,default]'))
  end

  it "parses a parameterized type into the type object" do
    parameterized_array = types.array_of(types.integer)
    parameterized_hash = types.hash_of(types.integer, types.boolean)

    expect(the_type_parsed_from(parameterized_array)).to be_the_type(parameterized_array)
    expect(the_type_parsed_from(parameterized_hash)).to be_the_type(parameterized_hash)
  end

  it "parses a size constrained collection using capped range" do
    parameterized_array = types.array_of(types.integer, types.range(1,2))
    parameterized_hash = types.hash_of(types.integer, types.boolean, types.range(1,2))

    expect(the_type_parsed_from(parameterized_array)).to be_the_type(parameterized_array)
    expect(the_type_parsed_from(parameterized_hash)).to be_the_type(parameterized_hash)
  end

  it "parses a size constrained collection with open range" do
    parameterized_array = types.array_of(types.integer, types.range(1, :default))
    parameterized_hash = types.hash_of(types.integer, types.boolean, types.range(1, :default))

    expect(the_type_parsed_from(parameterized_array)).to be_the_type(parameterized_array)
    expect(the_type_parsed_from(parameterized_hash)).to be_the_type(parameterized_hash)
  end

  it "parses optional type" do
    opt_t = types.optional(Integer)
    expect(the_type_parsed_from(opt_t)).to be_the_type(opt_t)
  end

  it "parses tuple type" do
    tuple_t = types.tuple([Integer, String])
    expect(the_type_parsed_from(tuple_t)).to be_the_type(tuple_t)
  end

  it "parses tuple type with occurrence constraint" do
    tuple_t = types.tuple([Integer, String], types.range(2, 5))
    expect(the_type_parsed_from(tuple_t)).to be_the_type(tuple_t)
  end

  it "parses struct type" do
    struct_t = types.struct({'a'=>Integer, 'b'=>String})
    expect(the_type_parsed_from(struct_t)).to be_the_type(struct_t)
  end

  describe "handles parsing of patterns and regexp" do
    { 'Pattern[/([a-z]+)([1-9]+)/]'        => [:pattern, [/([a-z]+)([1-9]+)/]],
      'Pattern["([a-z]+)([1-9]+)"]'        => [:pattern, [/([a-z]+)([1-9]+)/]],
      'Regexp[/([a-z]+)([1-9]+)/]'         => [:regexp,  [/([a-z]+)([1-9]+)/]],
      'Pattern[/x9/, /([a-z]+)([1-9]+)/]'  => [:pattern, [/x9/, /([a-z]+)([1-9]+)/]],
    }.each do |source, type|
      it "such that the source '#{source}' yields the type #{type.to_s}" do
        expect(parser.parse(source)).to be_the_type(TypeFactory.send(type[0], *type[1]))
      end
    end
  end

  it "rejects an collection spec with the wrong number of parameters" do
    expect { parser.parse("Array[Integer, 1,2,3]") }.to raise_the_parameter_error("Array", "1 to 3", 4)
    expect { parser.parse("Hash[Integer, Integer, 1,2,3]") }.to raise_the_parameter_error("Hash", "2 to 4", 5)
  end

  context 'with scope context and loader' do
    let!(:scope) { {} }
    let(:loader) { Object.new }

    before :each do
      Adapters::LoaderAdapter.expects(:loader_for_model_object).with(instance_of(Model::QualifiedReference), scope).at_most_once.returns loader
    end

    it 'interprets anything that is not found by the loader to be a type reference' do
      loader.expects(:load).with(:type, 'nonesuch').returns nil
      expect(parser.parse('Nonesuch', scope)).to be_the_type(types.type_reference('Nonesuch'))
    end

    it 'interprets anything that is found by the loader to be what the loader found' do
      loader.expects(:load).with(:type, 'file').returns types.resource('File')
      expect(parser.parse('File', scope)).to be_the_type(types.resource('File'))
    end

    it "parses a resource type with title" do
      loader.expects(:load).with(:type, 'file').returns types.resource('File')
      expect(parser.parse("File['/tmp/foo']", scope)).to be_the_type(types.resource('file', '/tmp/foo'))
    end

    it "parses a resource type using 'Resource[type]' form" do
      loader.expects(:load).with(:type, 'file').returns types.resource('File')
      expect(parser.parse("Resource[File]", scope)).to be_the_type(types.resource('file'))
    end

    it "parses a resource type with title using 'Resource[type, title]'" do
      loader.expects(:load).with(:type, 'file').returns nil
      expect(parser.parse("Resource[File, '/tmp/foo']", scope)).to be_the_type(types.resource('file', '/tmp/foo'))
    end

    it "parses a resource type with title using 'Resource[Type[title]]'" do
      loader.expects(:load).with(:type, 'nonesuch').returns nil
      expect(parser.parse("Resource[Nonesuch['fife']]", scope)).to be_the_type(types.resource('nonesuch', 'fife'))
    end
  end

  context 'with loader context' do
    let(:loader) { Puppet::Pops::Loader::BaseLoader.new(nil, "type_parser_unit_test_loader") }
    before :each do
      Puppet::Pops::Adapters::LoaderAdapter.expects(:loader_for_model_object).never
    end

    it 'interprets anything that is not found by the loader to be a type reference' do
      loader.expects(:load).with(:type, 'nonesuch').returns nil
      expect(parser.parse('Nonesuch', loader)).to be_the_type(types.type_reference('Nonesuch'))
    end

    it 'interprets anything that is found by the loader to be what the loader found' do
      loader.expects(:load).with(:type, 'file').returns types.resource('File')
      expect(parser.parse('File', loader)).to be_the_type(types.resource('file'))
    end

    it "parses a resource type with title" do
      loader.expects(:load).with(:type, 'file').returns types.resource('File')
      expect(parser.parse("File['/tmp/foo']", loader)).to be_the_type(types.resource('file', '/tmp/foo'))
    end

    it "parses a resource type using 'Resource[type]' form" do
      loader.expects(:load).with(:type, 'file').returns types.resource('File')
      expect(parser.parse("Resource[File]", loader)).to be_the_type(types.resource('file'))
    end

    it "parses a resource type with title using 'Resource[type, title]'" do
      loader.expects(:load).with(:type, 'file').returns types.resource('File')
      expect(parser.parse("Resource[File, '/tmp/foo']", loader)).to be_the_type(types.resource('file', '/tmp/foo'))
    end
  end

  context 'without a scope' do
    it "interprets anything that is not a built in type to be a type reference" do
      expect(parser.parse('File')).to eq(types.type_reference('File'))
    end

    it "interprets anything that is not a built in type with parameterers to be type reference with parameters" do
      expect(parser.parse("File['/tmp/foo']")).to eq(types.type_reference("File['/tmp/foo']"))
    end
  end

  it "parses a host class type" do
    expect(parser.parse("Class")).to be_the_type(types.host_class())
  end

  it "parses a parameterized host class type" do
    expect(parser.parse("Class[foo::bar]")).to be_the_type(types.host_class('foo::bar'))
  end

  it 'parses an integer range' do
   expect(parser.parse("Integer[1,2]")).to be_the_type(types.range(1,2))
  end

  it 'parses a negative integer range' do
    expect(parser.parse("Integer[-3,-1]")).to be_the_type(types.range(-3,-1))
  end

  it 'parses a float range' do
   expect(parser.parse("Float[1.0,2.0]")).to be_the_type(types.float_range(1.0,2.0))
  end

  it 'parses a collection size range' do
   expect(parser.parse("Collection[1,2]")).to be_the_type(types.collection(types.range(1,2)))
  end

  it 'parses a type type' do
    expect(parser.parse("Type[Integer]")).to be_the_type(types.type_type(types.integer))
  end

  it 'parses a ruby type' do
    expect(parser.parse("Runtime[ruby, 'Integer']")).to be_the_type(types.ruby_type('Integer'))
  end

  it 'parses a callable type' do
    expect(parser.parse("Callable")).to be_the_type(types.all_callables())
  end

  it 'parses a parameterized callable type' do
    expect(parser.parse("Callable[String, Integer]")).to be_the_type(types.callable(String, Integer))
  end

  it 'parses a parameterized callable type with min/max' do
    expect(parser.parse("Callable[String, Integer, 1, default]")).to be_the_type(types.callable(String, Integer, 1, :default))
  end

  it 'parses a parameterized callable type with block' do
    expect(parser.parse("Callable[String, Callable[Boolean]]")).to be_the_type(types.callable(String, types.callable(true)))
  end

  it 'parses a parameterized callable type with 0 min/max' do
    t = parser.parse("Callable[0,0]")
    expect(t).to be_the_type(types.callable(0,0))
    expect(t.param_types.types).to be_empty
  end

  it 'parses a parameterized callable type with >0 min/max' do
    t = parser.parse("Callable[0,1]")
    expect(t).to be_the_type(types.callable(0,1))
    # Contains a Unit type to indicate "called with what you accept"
    expect(t.param_types.types[0]).to be_the_type(PUnitType.new())
  end

  it 'parses all known literals' do
    t = parser.parse('Nonesuch[{a=>undef,b=>true,c=>false,d=>default,e=>"string",f=>0,g=>1.0,h=>[1,2,3]}]')
    expect(t).to be_a(PTypeReferenceType)
    expect(t.type_string).to eql('Nonesuch[{a=>undef,b=>true,c=>false,d=>default,e=>"string",f=>0,g=>1.0,h=>[1,2,3]}]')
  end

  matcher :be_the_type do |type|
    calc = TypeCalculator.new

    match do |actual|
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end

    failure_message do |actual|
      "expected #{calc.string(type)}, but was #{calc.string(actual)}"
    end
  end

  def raise_the_parameter_error(type, required, given)
    raise_error(Puppet::ParseError, /#{type} requires #{required}, #{given} provided/)
  end

  def raise_type_error_for(type_name)
    raise_error(Puppet::ParseError, /Unknown type <#{type_name}>/)
  end

  def raise_unparameterized_error_for(type_name)
    raise_error(Puppet::ParseError, /Not a parameterized type <#{type_name}>/)
  end

  def the_type_parsed_from(type)
    parser.parse(the_type_spec_for(type))
  end

  def the_type_spec_for(type)
    TypeFormatter.string(type)
  end
end
end
end
