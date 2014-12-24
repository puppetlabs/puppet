#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/node'
require 'puppet/indirector/node/msgpack'

describe Puppet::Node::Msgpack, :if => Puppet.features.msgpack? do
  it "should be a subclass of the Msgpack terminus" do
    expect(Puppet::Node::Msgpack.superclass).to equal(Puppet::Indirector::Msgpack)
  end

  it "should have documentation" do
    expect(Puppet::Node::Msgpack.doc).not_to be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:node)
    expect(Puppet::Node::Msgpack.indirection).to equal(indirection)
  end

  it "should have its name set to :msgpack" do
    expect(Puppet::Node::Msgpack.name).to eq(:msgpack)
  end
end
