#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::ASTArray do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should have a [] accessor" do
    array = Puppet::Parser::AST::ASTArray.new :children => []
    array.should respond_to(:[])
  end

  it "should evaluate all its children" do
    item1 = stub "item1", :is_a? => true
    item2 = stub "item2", :is_a? => true

    item1.expects(:safeevaluate).with(@scope).returns(123)
    item2.expects(:safeevaluate).with(@scope).returns(246)

    operator = Puppet::Parser::AST::ASTArray.new :children => [item1,item2]
    operator.evaluate(@scope)
  end

  it "should not flatten children coming from children ASTArray" do
    item = Puppet::Parser::AST::String.new :value => 'foo'
    inner_array = Puppet::Parser::AST::ASTArray.new :children => [item, item]
    operator = Puppet::Parser::AST::ASTArray.new :children => [inner_array, inner_array]
    operator.evaluate(@scope).should == [['foo', 'foo'], ['foo', 'foo']]
  end

  it "should not flatten the results of children evaluation" do
    item = Puppet::Parser::AST::String.new :value => 'foo'
    item.stubs(:evaluate).returns(['foo'])
    operator = Puppet::Parser::AST::ASTArray.new :children => [item, item]
    operator.evaluate(@scope).should == [['foo'], ['foo']]
  end

  it "should discard nil results from children evaluation" do
    item1 = Puppet::Parser::AST::String.new :value => 'foo'
    item2 = Puppet::Parser::AST::String.new :value => 'foo'
    item2.stubs(:evaluate).returns(nil)
    operator = Puppet::Parser::AST::ASTArray.new :children => [item1, item2]
    operator.evaluate(@scope).should == ['foo']
  end

  it "should return a valid string with to_s" do
    a = stub 'a', :is_a? => true, :to_s => "a"
    b = stub 'b', :is_a? => true, :to_s => "b"
    array = Puppet::Parser::AST::ASTArray.new :children => [a,b]

    array.to_s.should == "[a, b]"
  end
end
