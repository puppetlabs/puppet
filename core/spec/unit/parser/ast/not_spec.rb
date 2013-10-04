#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::Not do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
    @true_ast = Puppet::Parser::AST::Boolean.new( :value => true)
    @false_ast = Puppet::Parser::AST::Boolean.new( :value => false)
  end

  it "should evaluate its child expression" do
    val = stub "val"
    val.expects(:safeevaluate).with(@scope)

    operator = Puppet::Parser::AST::Not.new :value => val
    operator.evaluate(@scope)
  end

  it "should return true for ! false" do
    operator = Puppet::Parser::AST::Not.new :value => @false_ast
    operator.evaluate(@scope).should == true
  end

  it "should return false for ! true" do
    operator = Puppet::Parser::AST::Not.new :value => @true_ast
    operator.evaluate(@scope).should == false
  end

end
