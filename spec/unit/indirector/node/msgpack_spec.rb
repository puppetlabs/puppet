#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/node'
require 'puppet/indirector/node/msgpack'

describe Puppet::Node::Msgpack, :if => Puppet.features.msgpack? do
  it "should be a subclass of the Msgpack terminus" do
    Puppet::Node::Msgpack.superclass.should equal(Puppet::Indirector::Msgpack)
  end

  it "should have documentation" do
    Puppet::Node::Msgpack.doc.should_not be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:node)
    Puppet::Node::Msgpack.indirection.should equal(indirection)
  end

  it "should have its name set to :msgpack" do
    Puppet::Node::Msgpack.name.should == :msgpack
  end
end
