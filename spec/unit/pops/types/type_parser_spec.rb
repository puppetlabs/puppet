require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Types::TypeParser do
  extend RSpec::Matchers::DSL

  let(:parser) { Puppet::Pops::Types::TypeParser.new }
  let(:types) { Puppet::Pops::Types::TypeFactory }

  it "rejects an invalid type simple type" do
    expect { parser.parse("NotAType") }.to raise_type_error_for("NotAType")
  end

  it "rejects an unknown parameterized type" do
    expect { parser.parse("NotAType[Integer]") }.to raise_type_error_for("NotAType")
  end

  it "does not support types that do not make sense in the puppet language" do
    expect { parser.parse("Object") }.to raise_type_error_for("Object")
    expect { parser.parse("Collection[Integer]") }.to raise_type_error_for("Collection")
  end

  it "parses a simple, unparameterized type into the type object" do
    expect(the_type_parsed_from(types.integer)).to be_the_type(types.integer)
    expect(the_type_parsed_from(types.float)).to be_the_type(types.float)
    expect(the_type_parsed_from(types.string)).to be_the_type(types.string)
    expect(the_type_parsed_from(types.boolean)).to be_the_type(types.boolean)
    expect(the_type_parsed_from(types.pattern)).to be_the_type(types.pattern)
    expect(the_type_parsed_from(types.data)).to be_the_type(types.data)
  end

  it "parses a parameterized type into the type object" do
    parameterized_array = types.array_of(types.integer)
    parameterized_hash = types.hash_of(types.integer, types.boolean)

    expect(the_type_parsed_from(parameterized_array)).to be_the_type(parameterized_array)
    expect(the_type_parsed_from(parameterized_hash)).to be_the_type(parameterized_hash)
  end

  it "rejects an array spec with the wrong number of parameters" do
    expect { parser.parse("Array[Integer, Integer]") }.to raise_the_parameter_error("Array", 1, 2)
    expect { parser.parse("Hash[Integer]") }.to raise_the_parameter_error("Hash", 2, 1)
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

  def the_type_parsed_from(type)
    parser.parse(the_type_spec_for(type))
  end

  def the_type_spec_for(type)
    calc = Puppet::Pops::Types::TypeCalculator.new
    calc.string(type)
  end
end
