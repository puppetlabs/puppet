#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/parser/ast/in_operator'

describe Puppet::Parser::AST::InOperator do
  before :each do
    @scope = Puppet::Parser::Scope.new

    @lval = stub 'lval'
    @lval.stubs(:safeevaluate).with(@scope).returns("left")

    @rval = stub 'rval'
    @rval.stubs(:safeevaluate).with(@scope).returns("right")

    @operator = Puppet::Parser::AST::InOperator.new :lval => @lval, :rval => @rval
  end

  it "should evaluate the left operand" do
    @lval.expects(:safeevaluate).with(@scope).returns("string")

    @operator.evaluate(@scope)
  end

  it "should evaluate the right operand" do
    @rval.expects(:safeevaluate).with(@scope).returns("string")

    @operator.evaluate(@scope)
  end

  it "should raise an argument error if lval is not a string" do
    @lval.expects(:safeevaluate).with(@scope).returns([12,13])

    lambda { @operator.evaluate(@scope) }.should raise_error
  end

  it "should raise an argument error if rval doesn't support the include? method" do
    @rval.expects(:safeevaluate).with(@scope).returns(stub('value'))

    lambda { @operator.evaluate(@scope) }.should raise_error
  end

  it "should not raise an argument error if rval supports the include? method" do
    @rval.expects(:safeevaluate).with(@scope).returns(stub('value', :include? => true))

    lambda { @operator.evaluate(@scope) }.should_not raise_error
  end

  it "should return rval.include?(lval)" do
    lval = stub 'lvalue', :is_a? => true
    @lval.stubs(:safeevaluate).with(@scope).returns(lval)

    rval = stub 'rvalue'
    @rval.stubs(:safeevaluate).with(@scope).returns(rval)
    rval.expects(:include?).with(lval).returns(:result)

    @operator.evaluate(@scope).should == :result
  end
end
