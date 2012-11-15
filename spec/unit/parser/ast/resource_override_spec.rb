#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::ResourceOverride do

  ast = Puppet::Parser::AST

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @scope = Puppet::Parser::Scope.new(@compiler)
    @params = ast::ASTArray.new({})
    @compiler.stubs(:add_override)
  end

  it "should evaluate the overriden object" do
    klass = stub 'klass', :title => "title", :type => "type"
    object = mock 'object'
    object.expects(:safeevaluate).with(@scope).returns(klass)
    ast::ResourceOverride.new(:object => object, :parameters => @params ).evaluate(@scope)
  end

  it "should tell the compiler to override the resource with our own" do
    @compiler.expects(:add_override)

    klass = stub 'klass', :title => "title", :type => "one"
    object = mock 'object', :safeevaluate => klass
    ast::ResourceOverride.new(:object => object , :parameters => @params).evaluate(@scope)
  end

  it "should return the overriden resource directly when called with one item" do
    klass = stub 'klass', :title => "title", :type => "one"
    object = mock 'object', :safeevaluate => klass
    override = ast::ResourceOverride.new(:object => object , :parameters => @params).evaluate(@scope)
    override.should be_an_instance_of(Puppet::Parser::Resource)
    override.title.should == "title"
    override.type.should == "One"
  end

  it "should return an array of overriden resources when called with an array of titles" do
    klass1 = stub 'klass1', :title => "title1", :type => "one"
    klass2 = stub 'klass2', :title => "title2", :type => "one"

    object = mock 'object', :safeevaluate => [klass1,klass2]

    override = ast::ResourceOverride.new(:object => object , :parameters => @params).evaluate(@scope)
    override.should have(2).elements
    override.each {|o| o.should be_an_instance_of(Puppet::Parser::Resource) }
  end

end
