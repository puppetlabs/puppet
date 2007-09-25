#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node/configuration'
require 'puppet/indirector/yaml/configuration'

describe Puppet::Indirector::Yaml::Configuration do
    it "should be a subclass of the Yaml terminus" do
        Puppet::Indirector::Yaml::Configuration.superclass.should equal(Puppet::Indirector::Yaml)
    end

    it "should have documentation" do
        Puppet::Indirector::Yaml::Configuration.doc.should_not be_nil
    end

    it "should be registered with the configuration store indirection" do
        indirection = Puppet::Indirector::Indirection.instance(:configuration)
        Puppet::Indirector::Yaml::Configuration.indirection.should equal(indirection)
    end

    it "should have its name set to :configuration" do
        Puppet::Indirector::Yaml::Configuration.name.should == :configuration
    end
end
