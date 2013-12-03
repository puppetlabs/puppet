require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Types::TypeParser do
  extend RSpec::Matchers::DSL

  let(:parser) { Puppet::Pops::Types::TypeParser.new }
  let(:types) { Puppet::Pops::Types::TypeFactory }

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

  it "does not support types that do not make sense in the puppet language" do
    # These will/may make sense later, but are not yet implemented and should not be interpreted as a PResourceType
    expect { parser.parse("Ruby") }.to raise_type_error_for("Ruby")
    expect { parser.parse("Type") }.to raise_type_error_for("Type")
  end

  [
    'Object', 'Collection', 'Data', 'CatalogEntry', 'Boolean', 'Literal', 'Undef', 'Numeric',
  ].each do |name|
    it "does not support parameterizing unparameterized type <#{name}" do
      expect { parser.parse("#{name}[Integer]") }.to raise_unparameterized_error_for(name)
    end
  end

  it "parses a simple, unparameterized type into the type object" do
    expect(the_type_parsed_from(types.object)).to be_the_type(types.object)
    expect(the_type_parsed_from(types.integer)).to be_the_type(types.integer)
    expect(the_type_parsed_from(types.float)).to be_the_type(types.float)
    expect(the_type_parsed_from(types.string)).to be_the_type(types.string)
    expect(the_type_parsed_from(types.boolean)).to be_the_type(types.boolean)
    expect(the_type_parsed_from(types.pattern)).to be_the_type(types.pattern)
    expect(the_type_parsed_from(types.data)).to be_the_type(types.data)
    expect(the_type_parsed_from(types.catalog_entry)).to be_the_type(types.catalog_entry)
    expect(the_type_parsed_from(types.collection)).to be_the_type(types.collection)
  end

  it "interprets an unparameterized Array as an Array of Data" do
    expect(parser.parse("Array")).to be_the_type(types.array_of_data)
  end

  it "interprets an unparameterized Hash as a Hash of Literal to Data" do
    expect(parser.parse("Hash")).to be_the_type(types.hash_of_data)
  end

  it "interprets a parameterized Hash[t] as a Hash of Literal to t" do
    expect(parser.parse("Hash[Integer]")).to be_the_type(types.hash_of(types.integer))
  end

  it "parses a parameterized type into the type object" do
    parameterized_array = types.array_of(types.integer)
    parameterized_hash = types.hash_of(types.integer, types.boolean)

    expect(the_type_parsed_from(parameterized_array)).to be_the_type(parameterized_array)
    expect(the_type_parsed_from(parameterized_hash)).to be_the_type(parameterized_hash)
  end

  it "rejects an array spec with the wrong number of parameters" do
    expect { parser.parse("Array[Integer, Integer]") }.to raise_the_parameter_error("Array", 1, 2)
    expect { parser.parse("Hash[Integer, Integer, Integer]") }.to raise_the_parameter_error("Hash", "1 or 2", 3)
  end

  it "interprets anything that is not a built in type to be a resource type" do
    expect(parser.parse("File")).to be_the_type(types.resource('file'))
  end

  it "parses a resource type with title" do
    expect(parser.parse("File['/tmp/foo']")).to be_the_type(types.resource('file', '/tmp/foo'))
  end

  it "parses a resource type using 'Resource[type]' form" do
    expect(parser.parse("Resource[File]")).to be_the_type(types.resource('file'))
  end

  it "parses a resource type with title using 'Resource[type, title]'" do
    expect(parser.parse("Resource[File, '/tmp/foo']")).to be_the_type(types.resource('file', '/tmp/foo'))
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

  it 'parses a float range' do
   expect(parser.parse("Float[1.0,2.0]")).to be_the_type(types.float_range(1.0,2.0))
  end

  matcher :be_the_type do |type|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |actual|
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end

    failure_message_for_should do |actual|
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
    calc = Puppet::Pops::Types::TypeCalculator.new
    calc.string(type)
  end
end
