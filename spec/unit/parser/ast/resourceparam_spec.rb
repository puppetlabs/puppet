#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::ResourceParam do

  ast = Puppet::Parser::AST

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @scope = Puppet::Parser::Scope.new(@compiler)
    @params = ast::ASTArray.new({})
    @compiler.stubs(:add_override)
  end

  it "should evaluate the parameter value" do
    object = mock 'object'
    object.expects(:safeevaluate).with(@scope).returns('value')
    ast::ResourceParam.new(:param => 'myparam', :value => object).evaluate(@scope)
  end

  it "should return a Puppet::Parser::Resource::Param on evaluation" do
    object = mock 'object'
    object.expects(:safeevaluate).with(@scope).returns('value')
    evaled = ast::ResourceParam.new(:param => 'myparam', :value => object).evaluate(@scope)
    evaled.should be_a(Puppet::Parser::Resource::Param)
    evaled.name.to_s.should == 'myparam'
    evaled.value.to_s.should == 'value'
  end

  it "should copy line numbers to Puppet::Parser::Resource::Param" do
    object = mock 'object'
    object.expects(:safeevaluate).with(@scope).returns('value')
    evaled = ast::ResourceParam.new(:param => 'myparam', :value => object, :line => 42).evaluate(@scope)
    evaled.line.should == 42
  end

  it "should copy source file to Puppet::Parser::Resource::Param" do
    object = mock 'object'
    object.expects(:safeevaluate).with(@scope).returns('value')
    evaled = ast::ResourceParam.new(:param => 'myparam', :value => object, :file => 'foo.pp').evaluate(@scope)
    evaled.file.should == 'foo.pp'
  end

  it "should change nil parameter values to undef" do
    object = mock 'object'
    object.expects(:safeevaluate).with(@scope).returns(nil)
    evaled = ast::ResourceParam.new(:param => 'myparam', :value => object).evaluate(@scope)
    evaled.should be_a(Puppet::Parser::Resource::Param)
    evaled.value.should == :undef
  end
end
