#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'defined' function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(@compiler)
  end

  it "exists" do
    expect(Puppet::Parser::Functions.function("defined")).to be_eql("function_defined")
  end

  it "is true when the name is defined as a class" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "yayness")
    expect(@scope.function_defined(["yayness"])).to be_true
  end

  it "is true when the name is defined as a definition" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    expect(@scope.function_defined(["yayness"])).to be_true
  end

  it "is true when the name is defined as a builtin type" do
    expect(@scope.function_defined(["file"])).to be_true
  end

  it "is true when any of the provided names are defined" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    expect(@scope.function_defined(["meh", "yayness", "booness"])).to be_true
  end

  it "is false when a single given name is not defined" do
    expect(@scope.function_defined(["meh"])).to be_false
  end

  it "is false when none of the names are defined" do
    expect(@scope.function_defined(["meh", "yayness", "booness"])).to be_false
  end

  it "is true when a resource reference is provided and the resource is in the catalog" do
    resource = Puppet::Resource.new("file", "/my/file")
    @compiler.add_resource(@scope, resource)
    expect(@scope.function_defined([resource])).to be_true
  end
end
