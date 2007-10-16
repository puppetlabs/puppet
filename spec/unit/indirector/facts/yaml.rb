#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node/facts'
require 'puppet/indirector/facts/yaml'

describe Puppet::Node::Facts::Yaml do
    it "should be a subclass of the Yaml terminus" do
        Puppet::Node::Facts::Yaml.superclass.should equal(Puppet::Indirector::Yaml)
    end


    it "should have documentation" do
        Puppet::Node::Facts::Yaml.doc.should_not be_nil
    end

    it "should be registered with the facts indirection" do
        indirection = Puppet::Indirector::Indirection.instance(:facts)
        Puppet::Node::Facts::Yaml.indirection.should equal(indirection)
    end

    it "should have its name set to :facts" do
        Puppet::Node::Facts::Yaml.name.should == :yaml
    end
end
