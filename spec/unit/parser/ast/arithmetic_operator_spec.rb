#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::ArithmeticOperator do

  ast = Puppet::Parser::AST

  before :each do
    @scope = Puppet::Parser::Scope.new
    @one = stub 'lval', :safeevaluate => 1
    @two = stub 'rval', :safeevaluate => 2
  end

  it "should evaluate both branches" do
    lval = stub "lval"
    lval.expects(:safeevaluate).with(@scope).returns(1)
    rval = stub "rval"
    rval.expects(:safeevaluate).with(@scope).returns(2)

    operator = ast::ArithmeticOperator.new :rval => rval, :operator => "+", :lval => lval
    operator.evaluate(@scope)
  end

  it "should fail for an unknown operator" do
    lambda { operator = ast::ArithmeticOperator.new :lval => @one, :operator => "%", :rval => @two }.should raise_error
  end

  it "should call Puppet::Parser::Scope.number?" do
    Puppet::Parser::Scope.expects(:number?).with(1).returns(1)
    Puppet::Parser::Scope.expects(:number?).with(2).returns(2)

    ast::ArithmeticOperator.new(:lval => @one, :operator => "+", :rval => @two).evaluate(@scope)
  end


  %w{ + - * / << >>}.each do |op|
    it "should call ruby Numeric '#{op}'" do
      one = stub 'one'
      two = stub 'two'
      operator = ast::ArithmeticOperator.new :lval => @one, :operator => op, :rval => @two
      Puppet::Parser::Scope.stubs(:number?).with(1).returns(one)
      Puppet::Parser::Scope.stubs(:number?).with(2).returns(two)
      one.expects(:send).with(op,two)
      operator.evaluate(@scope)
    end
  end

  it "should work even with numbers embedded in strings" do
    two = stub 'two', :safeevaluate => "2"
    one = stub 'one', :safeevaluate => "1"
    operator = ast::ArithmeticOperator.new :lval => two, :operator => "+", :rval => one
    operator.evaluate(@scope).should == 3
  end

  it "should work even with floats" do
    two = stub 'two', :safeevaluate => 2.53
    one = stub 'one', :safeevaluate => 1.80
    operator = ast::ArithmeticOperator.new :lval => two, :operator => "+", :rval => one
    operator.evaluate(@scope).should == 4.33
  end

end
