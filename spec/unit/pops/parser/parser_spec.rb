require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Parser::Parser do
  it "should instantiate a parser" do
    parser = Puppet::Pops::Parser::Parser.new()
    parser.class.should == Puppet::Pops::Parser::Parser
  end

  it "should parse a code string and return a model" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("$a = 10").current
    model.class.should == Model::AssignmentExpression
  end
end
