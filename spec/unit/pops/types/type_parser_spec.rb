require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Types::TypeParser do
  extend RSpec::Matchers::DSL

  let(:parser) { Puppet::Pops::Types::TypeParser.new }
  let(:types) { Puppet::Pops::Types::TypeFactory }

  it "rejects an invalide type" do
    expect { parser.parse("NotAType") }.to raise_error(Puppet::ParseError, /Unknown type <NotAType>/)
  end

  it "parses a simple, unparameterized type into the type object" do
    expect(parser.parse(the_type_spec_for(types.integer))).to be_the_type(types.integer)
    expect(parser.parse(the_type_spec_for(types.float))).to be_the_type(types.float)
    expect(parser.parse(the_type_spec_for(types.string))).to be_the_type(types.string)
    expect(parser.parse(the_type_spec_for(types.boolean))).to be_the_type(types.boolean)
    expect(parser.parse(the_type_spec_for(types.pattern))).to be_the_type(types.pattern)
    expect(parser.parse(the_type_spec_for(types.data))).to be_the_type(types.data)
    expect(parser.parse(the_type_spec_for(types.object))).to be_the_type(types.object)
  end

  matcher :be_the_type do |type|
    match do |actual|
      calc = Puppet::Pops::Types::TypeCalculator.new
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end
  end

  def the_type_spec_for(type)
    calc = Puppet::Pops::Types::TypeCalculator.new
    calc.string(type)
  end
end
