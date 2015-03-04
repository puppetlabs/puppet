#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/node'
require 'puppet/indirector/node/yaml'

describe Puppet::Node::Yaml do
  it "should be a subclass of the Yaml terminus" do
    expect(Puppet::Node::Yaml.superclass).to equal(Puppet::Indirector::Yaml)
  end

  it "should have documentation" do
    expect(Puppet::Node::Yaml.doc).not_to be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:node)
    expect(Puppet::Node::Yaml.indirection).to equal(indirection)
  end

  it "should have its name set to :node" do
    expect(Puppet::Node::Yaml.name).to eq(:yaml)
  end
end
