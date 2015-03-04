#! /usr/bin/env ruby
require 'spec_helper'

describe "The require function" do
  before :each do
    @node = Puppet::Node.new("mynode")
    @compiler = Puppet::Parser::Compiler.new(@node)

    @compiler.send(:evaluate_main)
    @compiler.catalog.client_version = "0.25"
    @scope = @compiler.topscope
    # preload our functions
    Puppet::Parser::Functions.function(:include)
    Puppet::Parser::Functions.function(:require)
  end

  it "should add a dependency between the 'required' class and our class" do
    @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "requiredclass")

    @scope.function_require(["requiredclass"])
    expect(@scope.resource["require"]).not_to be_nil
    ref = @scope.resource["require"].shift
    expect(ref.type).to eq("Class")
    expect(ref.title).to eq("Requiredclass")
  end

  it "should queue relationships between the 'required' class and our classes" do
    @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "requiredclass1")
    @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "requiredclass2")

    @scope.function_require(["requiredclass1"])
    @scope.function_require(["requiredclass2"])

    expect(@scope.resource["require"]).not_to be_nil

    (ref1,ref2) = @scope.resource["require"]
    expect(ref1.type).to eq("Class")
    expect(ref1.title).to eq("Requiredclass1")
    expect(ref2.type).to eq("Class")
    expect(ref2.title).to eq("Requiredclass2")
  end

end
