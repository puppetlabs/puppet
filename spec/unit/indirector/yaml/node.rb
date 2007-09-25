#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node'
require 'puppet/indirector/yaml/node'

describe Puppet::Indirector::Yaml::Node do
    it "should be a subclass of the Yaml terminus" do
        Puppet::Indirector::Yaml::Node.superclass.should equal(Puppet::Indirector::Yaml)
    end

    it "should have documentation" do
        Puppet::Indirector::Yaml::Node.doc.should_not be_nil
    end

    it "should be registered with the configuration store indirection" do
        indirection = Puppet::Indirector::Indirection.instance(:node)
        Puppet::Indirector::Yaml::Node.indirection.should equal(indirection)
    end

    it "should have its name set to :node" do
        Puppet::Indirector::Yaml::Node.name.should == :node
    end
end
