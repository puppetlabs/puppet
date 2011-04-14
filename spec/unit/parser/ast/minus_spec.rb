#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::Minus do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should evaluate its argument" do
    value = stub "value"
    value.expects(:safeevaluate).with(@scope).returns(123)

    operator = Puppet::Parser::AST::Minus.new :value => value
    operator.evaluate(@scope)
  end

  it "should fail if argument is not a string or integer" do
    array_ast = stub 'array_ast', :safeevaluate => [2]
    operator = Puppet::Parser::AST::Minus.new :value => array_ast
    lambda { operator.evaluate(@scope) }.should raise_error
  end

  it "should work with integer as string" do
    string = stub 'string', :safeevaluate => "123"
    operator = Puppet::Parser::AST::Minus.new :value => string
    operator.evaluate(@scope).should == -123
  end

  it "should work with integers" do
    int = stub 'int', :safeevaluate => 123
    operator = Puppet::Parser::AST::Minus.new :value => int
    operator.evaluate(@scope).should == -123
  end

end
