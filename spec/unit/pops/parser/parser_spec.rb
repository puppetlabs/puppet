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
    model.class.should == Puppet::Pops::Model::AssignmentExpression
  end

#  describe "when benchmarked" do
#
#    it "Pops Parser", :profile => true do
#      code = 'if true
#{
#10 + 10
#}
#else
#{
#"interpolate ${foo} and stuff"
#}
#'
#      parser = Puppet::Pops::Parser::Parser.new()
#      m = Benchmark.measure { 10000.times { parser.parse_string(code) }}
#      puts "Parser: #{m}"
#    end
#  end
end
