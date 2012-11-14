require 'spec_helper'
require 'puppet/pops/impl/parser/parser'
require 'puppet/pops/api'

describe Puppet::Pops::Impl::Parser::Parser do
  it "should instantiate a parser" do
    parser = Puppet::Pops::Impl::Parser::Parser.new()
    parser.class.should == Puppet::Pops::Impl::Parser::Parser
  end
  it "should parse a code string and return a model" do
    parser = Puppet::Pops::Impl::Parser::Parser.new()
    model = parser.parse_string("$a = 10").current
    model.class.should == Model::AssignmentExpression
  end
end