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
    @scope.resource["require"].should_not be_nil
    ref = @scope.resource["require"].shift
    ref.type.should == "Class"
    ref.title.should == "Requiredclass"
  end

  it "should queue relationships between the 'required' class and our classes" do
    @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "requiredclass1")
    @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "requiredclass2")

    @scope.function_require(["requiredclass1"])
    @scope.function_require(["requiredclass2"])

    @scope.resource["require"].should_not be_nil

    (ref1,ref2) = @scope.resource["require"]
    ref1.type.should == "Class"
    ref1.title.should == "Requiredclass1"
    ref2.type.should == "Class"
    ref2.title.should == "Requiredclass2"
  end

end
