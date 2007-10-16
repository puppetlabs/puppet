#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node/configuration'
require 'puppet/indirector/configuration/yaml'

describe Puppet::Node::Configuration::Yaml do
    it "should be a subclass of the Yaml terminus" do
        Puppet::Node::Configuration::Yaml.superclass.should equal(Puppet::Indirector::Yaml)
    end

    it "should have documentation" do
        Puppet::Node::Configuration::Yaml.doc.should_not be_nil
    end

    it "should be registered with the configuration store indirection" do
        indirection = Puppet::Indirector::Indirection.instance(:configuration)
        Puppet::Node::Configuration::Yaml.indirection.should equal(indirection)
    end

    it "should have its name set to :yaml" do
        Puppet::Node::Configuration::Yaml.name.should == :yaml
    end
end
