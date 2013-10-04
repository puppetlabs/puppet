#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/node'
require 'puppet/indirector/memory'
require 'puppet/indirector/node/store_configs'

class Puppet::Node::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Node::StoreConfigs do
  after :each do
    Puppet::Node.indirection.reset_terminus_class
    Puppet::Node.indirection.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
