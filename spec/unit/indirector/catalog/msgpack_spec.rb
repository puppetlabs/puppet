#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/resource/catalog'
require 'puppet/indirector/catalog/msgpack'

describe Puppet::Resource::Catalog::Msgpack, :if => Puppet.features.msgpack? do
  # This is it for local functionality: we don't *do* anything else.
  it "should be registered with the catalog store indirection" do
    expect(Puppet::Resource::Catalog.indirection.terminus(:msgpack)).
      to be_an_instance_of described_class
  end
end
