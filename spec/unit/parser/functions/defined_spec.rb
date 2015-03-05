#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe "the 'defined' function" do

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(@compiler)
  end

  it "exists" do
    expect(Puppet::Parser::Functions.function("defined")).to be_eql("function_defined")
  end

  it "is true when the name is defined as a class" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "yayness")
    expect(@scope.function_defined(["yayness"])).to be_truthy
  end

  it "is true when the name is defined as a definition" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    expect(@scope.function_defined(["yayness"])).to be_truthy
  end

  it "is true when the name is defined as a builtin type" do
    expect(@scope.function_defined(["file"])).to be_truthy
  end

  it "is true when any of the provided names are defined" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    expect(@scope.function_defined(["meh", "yayness", "booness"])).to be_truthy
  end

  it "is false when a single given name is not defined" do
    expect(@scope.function_defined(["meh"])).to be_falsey
  end

  it "is false when none of the names are defined" do
    expect(@scope.function_defined(["meh", "yayness", "booness"])).to be_falsey
  end

  it "is true when a resource reference is provided and the resource is in the catalog" do
    resource = Puppet::Resource.new("file", "/my/file")
    @compiler.add_resource(@scope, resource)
    expect(@scope.function_defined([resource])).to be_truthy
  end

  context "with string variable references" do
    it "is true when variable exists in scope" do
      @scope['x'] = 'something'
      expect(@scope.function_defined(['$x'])).to be_truthy
    end

    it "is true when absolute referenced variable exists in scope" do
      @compiler.topscope['x'] = 'something'
      # Without this magic linking, scope cannot find the global scope via the name ''
      # which is the name of "topscope". (This is one of many problems with the scope impl)
      # When running real code, scopes are always linked up this way.
      @scope.class_set('', @compiler.topscope)
      expect(@scope.function_defined(['$::x'])).to be_truthy
    end

    it "is true when ::variable exists in scope" do
      @compiler.topscope['x'] = 'something'
      expect(@scope.function_defined(['$::x'])).to be_truthy
    end

    it "is true when at least one variable exists in scope" do
      @scope['x'] = 'something'
      expect(@scope.function_defined(['$y', '$x', '$z'])).to be_truthy
    end

    it "is false when variable does not exist in scope" do
      expect(@scope.function_defined(['$x'])).to be_falsey
    end
  end

  it "is true when a resource type reference is provided, and the resource is in the catalog" do
    resource = Puppet::Resource.new("file", "/my/file")
    @compiler.add_resource(@scope, resource)

    resource_type = Puppet::Pops::Types::TypeFactory.resource('file', '/my/file')
    expect(@scope.function_defined([resource_type])).to be_truthy
  end

  it "raises an argument error if you ask if Resource is defined" do
    resource_type = Puppet::Pops::Types::TypeFactory.resource
    expect { @scope.function_defined([resource_type]) }.to raise_error(ArgumentError, /reference to all.*type/)
  end

  it "is true if referencing a built in type" do
    resource_type = Puppet::Pops::Types::TypeFactory.resource('file')
    expect(@scope.function_defined([resource_type])).to be_truthy
  end

  it "is true if referencing a defined type" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    resource_type = Puppet::Pops::Types::TypeFactory.resource('yayness')
    expect(@scope.function_defined([resource_type])).to be_truthy
  end

  it "is false if referencing an undefined type" do
    resource_type = Puppet::Pops::Types::TypeFactory.resource('barbershops')
    expect(@scope.function_defined([resource_type])).to be_falsey
  end

  it "is true when a class type is provided" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "cowabunga")

    class_type = Puppet::Pops::Types::TypeFactory.host_class("cowabunga")
    expect(@scope.function_defined([class_type])).to be_truthy
  end

  it "raises an argument error if you ask if Class is defined" do
    class_type = Puppet::Pops::Types::TypeFactory.host_class
    expect { @scope.function_defined([class_type]) }.to raise_error(ArgumentError, /reference to all.*class/)
  end

end
