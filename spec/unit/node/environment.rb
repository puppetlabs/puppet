#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/environment'

describe Puppet::Node::Environment do
    it "should provide a list of valid environments" do
        Puppet::Node::Environment.valid.should be_instance_of(Array)
    end

    it "should determine its list of valid environments from splitting the :environments setting on commas" do
        Puppet.settings.stubs(:value).with(:environments).returns("one,two")
        Puppet::Node::Environment.valid.collect { |e| e.to_s }.sort.should == %w{one two}.sort
    end

    it "should not use an environment when determining the list of valid environments" do
        Puppet.settings.expects(:value).with(:environments).returns("one,two")
        Puppet::Node::Environment.valid
    end

    it "should provide a means of identifying invalid environments" do
        Puppet.settings.expects(:value).with(:environments).returns("one,two")
        Puppet::Node::Environment.valid?(:three).should be_false
    end

    it "should provide a means of identifying valid environments" do
        Puppet.settings.expects(:value).with(:environments).returns("one,two")
        Puppet::Node::Environment.valid?(:one).should be_true
    end

    it "should be used to determine when an environment setting is valid" do
        Puppet.settings.expects(:value).with(:environments).returns("one,two")
        proc { Puppet.settings[:environment] = :three }.should raise_error(ArgumentError)
    end

    it "should use the default environment if no name is provided while initializing an environment" do
        Puppet.settings.expects(:value).with(:environments).returns("one,two")
        Puppet.settings.expects(:value).with(:environment).returns("one")
        Puppet::Node::Environment.new().name.should == :one
    end

    it "should treat environment instances as singletons" do
        Puppet.settings.stubs(:value).with(:environments).returns("one")
        Puppet::Node::Environment.new("one").should equal(Puppet::Node::Environment.new("one"))
    end

    it "should treat an environment specified as names or strings as equivalent" do
        Puppet.settings.stubs(:value).with(:environments).returns("one")
        Puppet::Node::Environment.new(:one).should equal(Puppet::Node::Environment.new("one"))
    end

    it "should fail if an invalid environment instance is asked for" do
        Puppet.settings.stubs(:value).with(:environments).returns("one,two")
        proc { Puppet::Node::Environment.new("three") }.should raise_error(ArgumentError)
    end

    it "should consider environments that are empty strings invalid" do
        Puppet::Node::Environment.valid?("").should be_false
    end

    it "should fail if a no-longer-valid environment instance is asked for" do
        Puppet.settings.expects(:value).with(:environments).returns("one")
        Puppet::Node::Environment.new("one")
        Puppet.settings.expects(:value).with(:environments).returns("two")
        proc { Puppet::Node::Environment.new("one") }.should raise_error(ArgumentError)
    end
end

describe Puppet::Node::Environment, " when modeling a specific environment" do
    before do
        Puppet.settings.expects(:value).with(:environments).returns("testing")
    end

    it "should have a method for returning the environment name" do
        Puppet::Node::Environment.new("testing").name.should == :testing
    end

    it "should provide an array-like accessor method for returning any environment-specific setting" do
        env = Puppet::Node::Environment.new("testing")
        env.should respond_to(:[])
    end

    it "should ask the Puppet settings instance for the setting qualified with the environment name" do
        Puppet.settings.expects(:value).with("myvar", :testing).returns("myval")
        env = Puppet::Node::Environment.new("testing")
        env["myvar"].should == "myval"
    end
end
