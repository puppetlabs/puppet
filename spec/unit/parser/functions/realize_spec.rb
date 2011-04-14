#!/usr/bin/env rspec
require 'spec_helper'

describe "the realize function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @collector = stub_everything 'collector'
    @scope = Puppet::Parser::Scope.new
    @compiler = stub 'compiler'
    @compiler.stubs(:add_collection).with(@collector)
    @scope.stubs(:compiler).returns(@compiler)
  end

  it "should exist" do
    Puppet::Parser::Functions.function("realize").should == "function_realize"
  end

  it "should create a Collector when called" do

    Puppet::Parser::Collector.expects(:new).returns(@collector)

    @scope.function_realize("test")
  end

  it "should assign the passed-in resources to the collector" do
    Puppet::Parser::Collector.stubs(:new).returns(@collector)

    @collector.expects(:resources=).with(["test"])

    @scope.function_realize("test")
  end

  it "should flatten the resources assigned to the collector" do
    Puppet::Parser::Collector.stubs(:new).returns(@collector)

    @collector.expects(:resources=).with(["test"])

    @scope.function_realize([["test"]])
  end

  it "should let the compiler know this collector" do
    Puppet::Parser::Collector.stubs(:new).returns(@collector)
    @collector.stubs(:resources=).with(["test"])

    @compiler.expects(:add_collection).with(@collector)

    @scope.function_realize("test")
  end

end
