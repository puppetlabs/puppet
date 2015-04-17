#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe "the 'defined' function" do
  after(:all) { Puppet::Pops::Loaders.clear }

  # This loads the function once and makes it easy to call it
  # It does not matter that it is not bound to the env used later since the function
  # looks up everything via the scope that is given to it.
  # The individual tests needs to have a fresh env/catalog set up
  #
  let(:loaders) { Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, [])) }
  let(:func) { loaders.puppet_system_loader.load(:function, 'defined') }

  before :each do
    # This is only for the 4.x version of the defined function
    Puppet[:parser] = 'future'
    # A fresh environment is needed for each test since tests creates types and resources
    environment = Puppet::Node::Environment.create(:testing, [])
    @node = Puppet::Node.new("yaynode", :environment => environment)
    @known_resource_types = environment.known_resource_types
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = Puppet::Parser::Scope.new(@compiler)
  end

  def newclass(name)
    @known_resource_types.add Puppet::Resource::Type.new(:hostclass, name)
  end

  def newdefine(name)
    @known_resource_types.add Puppet::Resource::Type.new(:definition, name)
  end

  def newresource(type, title)
    resource = Puppet::Resource.new(type, title)
    @compiler.add_resource(@scope, resource)
    resource
  end

  it "is true when the name is defined as a class" do
    newclass 'yayness'
    newresource(:class, 'yayness')
    expect(func.call(@scope, "yayness")).to be_true
  end

  it "is true when the name is defined as a definition" do
    newdefine "yayness"
    expect(func.call(@scope, "yayness")).to be_true
  end

  it "is true when the name is defined as a builtin type" do
    expect(func.call(@scope, "file")).to be_true
  end

  it "is true when any of the provided names are defined" do
    newdefine "yayness"
    expect(func.call(@scope, "meh", "yayness", "booness")).to be_true
  end

  it "is false when a single given name is not defined" do
    expect(func.call(@scope, "meh")).to be_false
  end

  it "is false when none of the names are defined" do
    expect(func.call(@scope, "meh", "yayness", "booness")).to be_false
  end

  it "is true when a resource reference is provided and the resource is in the catalog" do
    resource = newresource("file", "/my/file")
    expect(func.call(@scope, resource)).to be_true
  end

  context "with string variable references" do
    it "is true when variable exists in scope" do
      @scope['x'] = 'something'
      expect(func.call(@scope, '$x')).to be_true
    end

    it "is true when ::variable exists in scope" do
      @compiler.topscope['x'] = 'something'
      expect(func.call(@scope, '$::x')).to be_true
    end

    it "is true when at least one variable exists in scope" do
      @scope['x'] = 'something'
      expect(func.call(@scope, '$y', '$x', '$z')).to be_true
    end

    it "is false when variable does not exist in scope" do
      expect(func.call(@scope, '$x')).to be_false
    end
  end

  it "is true when a future resource type reference is provided, and the resource is in the catalog" do
    resource = newresource("file", "/my/file")
    resource_type = Puppet::Pops::Types::TypeFactory.resource('file', '/my/file')
    expect(func.call(@scope, resource_type)).to be_true
  end

  it "raises an argument error if you ask if Resource is defined" do
    resource_type = Puppet::Pops::Types::TypeFactory.resource
    expect { func.call(@scope, resource_type)}.to raise_error(ArgumentError, /reference to all.*type/)
  end

  it "is true if referencing a built in type" do
    resource_type = Puppet::Pops::Types::TypeFactory.resource('file')
    expect(func.call(@scope, resource_type)).to be_true
  end

  it "is true if referencing a defined type" do
    @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "yayness")
    resource_type = Puppet::Pops::Types::TypeFactory.resource('yayness')
    expect(func.call(@scope, resource_type)).to be_true
  end

  it "is false if referencing an undefined type" do
    resource_type = Puppet::Pops::Types::TypeFactory.resource('barbershops')
    expect(func.call(@scope, resource_type)).to be_false
  end

  it "is true when a future class reference type is provided (and class is included)" do
    name = "cowabunga"
    newclass name
    newresource(:class, name)
    class_type = Puppet::Pops::Types::TypeFactory.host_class(name)
    expect(func.call(@scope, class_type)).to be_true
  end

  it "is false when a future class reference type is provided (and class is not included)" do
    name = "cowabunga"
    newclass name
    class_type = Puppet::Pops::Types::TypeFactory.host_class(name)
    expect(func.call(@scope, class_type)).to be_false
  end

  it "raises an argument error if you ask if Class is defined" do
    class_type = Puppet::Pops::Types::TypeFactory.host_class
    expect { func.call(@scope, class_type) }.to raise_error(ArgumentError, /reference to all.*class/)
  end

  it "raises error if referencing undef" do
  expect{func.call(@scope, nil)}.to raise_error(ArgumentError, /mis-matched arguments/)
  end

  it "is false if referencing empty string" do
    expect(func.call(@scope, '')).to be_false
  end

  it "is true if referencing 'main'" do
    # mimic what compiler does with "main" in intial import
    newclass ''
    newresource :class, ''
    expect(func.call(@scope, 'main')).to be_true
  end

end
