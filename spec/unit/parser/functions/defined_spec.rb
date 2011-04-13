#!/usr/bin/env rspec
require 'spec_helper'

describe "the 'defined' function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    Puppet::Node::Environment.stubs(:current).returns(nil)
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(:compiler => @compiler)
  end

  it "should exist" do
    Puppet::Parser::Functions.function("defined").should == "function_defined"
  end

  it "should be true when the name is defined as a class" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "yayness")
    @scope.function_defined("yayness").should be_true
  end

  it "should be true when the name is defined as a definition" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    @scope.function_defined("yayness").should be_true
  end

  it "should be true when the name is defined as a builtin type" do
    @scope.function_defined("file").should be_true
  end


  it "should be true when any of the provided names are defined" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    @scope.function_defined(["meh", "yayness", "booness"]).should be_true
  end

  it "should be false when a single given name is not defined" do
    @scope.function_defined("meh").should be_false
  end

  it "should be false when none of the names are defined" do
    @scope.function_defined(["meh", "yayness", "booness"]).should be_false
  end

  it "should be true when a resource reference is provided and the resource is in the catalog" do
    resource = Puppet::Resource.new("file", "/my/file")
    @compiler.add_resource(@scope, resource)
    @scope.function_defined(resource).should be_true
  end
end
