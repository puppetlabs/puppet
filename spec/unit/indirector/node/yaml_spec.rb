#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/node'
require 'puppet/indirector/node/yaml'

describe Puppet::Node::Yaml do
  it "should be a subclass of the Yaml terminus" do
    Puppet::Node::Yaml.superclass.should equal(Puppet::Indirector::Yaml)
  end

  it "should have documentation" do
    Puppet::Node::Yaml.doc.should_not be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:node)
    Puppet::Node::Yaml.indirection.should equal(indirection)
  end

  it "should have its name set to :node" do
    Puppet::Node::Yaml.name.should == :yaml
  end
end
