#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/node/environment'

describe Puppet::Node::Environment do
    it "should use the default environment if no name is provided while initializing an environment" do
        Puppet.settings.expects(:value).with(:environment).returns("one")
        Puppet::Node::Environment.new().name.should == :one
    end

    it "should treat environment instances as singletons" do
        Puppet::Node::Environment.new("one").should equal(Puppet::Node::Environment.new("one"))
    end

    it "should treat an environment specified as names or strings as equivalent" do
        Puppet::Node::Environment.new(:one).should equal(Puppet::Node::Environment.new("one"))
    end
end

describe Puppet::Node::Environment, " when modeling a specific environment" do
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
