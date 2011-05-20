#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::BooleanOperator do

  ast = Puppet::Parser::AST

  before :each do
    @scope = Puppet::Parser::Scope.new
    @true_ast = ast::Boolean.new( :value => true)
    @false_ast = ast::Boolean.new( :value => false)
  end

  it "should evaluate left operand inconditionally" do
    lval = stub "lval"
    lval.expects(:safeevaluate).with(@scope).returns("true")
    rval = stub "rval", :safeevaluate => false
    rval.expects(:safeevaluate).never

    operator = ast::BooleanOperator.new :rval => rval, :operator => "or", :lval => lval
    operator.evaluate(@scope)
  end

  it "should evaluate right 'and' operand only if left operand is true" do
    lval = stub "lval", :safeevaluate => true
    rval = stub "rval", :safeevaluate => false
    rval.expects(:safeevaluate).with(@scope).returns(false)
    operator = ast::BooleanOperator.new :rval => rval, :operator => "and", :lval => lval
    operator.evaluate(@scope)
  end

  it "should evaluate right 'or' operand only if left operand is false" do
    lval = stub "lval", :safeevaluate => false
    rval = stub "rval", :safeevaluate => false
    rval.expects(:safeevaluate).with(@scope).returns(false)
    operator = ast::BooleanOperator.new :rval => rval, :operator => "or", :lval => lval
    operator.evaluate(@scope)
  end

  it "should return true for false OR true" do
    ast::BooleanOperator.new(:rval => @true_ast, :operator => "or", :lval => @false_ast).evaluate(@scope).should be_true
  end

  it "should return false for true AND false" do
    ast::BooleanOperator.new(:rval => @true_ast, :operator => "and", :lval => @false_ast ).evaluate(@scope).should be_false
  end

  it "should return true for true AND true" do
    ast::BooleanOperator.new(:rval => @true_ast, :operator => "and", :lval => @true_ast ).evaluate(@scope).should be_true
  end

end
