#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::MatchOperator do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
    @lval = Puppet::Parser::AST::String.new(:value => "this is a string")
    @rval = Puppet::Parser::AST::Regex.new(:value => "this is a string", :file => 'test.pp', :line => 1)
    @operator = Puppet::Parser::AST::MatchOperator.new :lval => @lval, :rval => @rval, :operator => "=~"
  end

  it "should evaluate the left operand" do
    @lval.expects(:safeevaluate).with(@scope)

    @operator.evaluate(@scope)
  end

  it "should fail for an unknown operator" do
    lambda { operator = Puppet::Parser::AST::MatchOperator.new :lval => @lval, :operator => "unknown", :rval => @rval }.should raise_error
  end

  it "should evaluate_match the left operand" do
    @rval.expects(:evaluate_match).with("this is a string", @scope).returns(:match)

    @operator.evaluate(@scope)
  end

  { "=~" => true, "!~" => false }.each do |op, res|
    it "should return #{res} if the regexp matches with #{op}" do
      operator = Puppet::Parser::AST::MatchOperator.new :lval => @lval, :rval => @rval, :operator => op
      operator.evaluate(@scope).should == res
    end

    it "should return #{!res} if the regexp doesn't match" do
      non_matching_string = Puppet::Parser::AST::String.new(:value => "not that string")
      operator = Puppet::Parser::AST::MatchOperator.new :lval => non_matching_string, :rval => @rval, :operator => op
      operator.evaluate(@scope).should == !res
    end
  end

  context 'has deprecations' do
    [1, 3.14, [1,2,3], {:a => 1}].each do |val|
      it "for non string lval #{val.to_s}" do
        value_stub = stub 'value_stub'
        value_stub.expects(:safeevaluate).with(@scope).returns(val)
        Puppet.expects(:deprecation_warning)
        operator = Puppet::Parser::AST::MatchOperator.new :lval => value_stub, :rval => @rval, :operator => "=~"
        operator.evaluate(@scope)
      end
    end
  end
end
