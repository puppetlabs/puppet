#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/node'
require 'puppet/indirector/memory'
require 'puppet/indirector/node/store_configs'

class Puppet::Node::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Node::StoreConfigs do
  after :each do
    Puppet::Node.terminus_class = nil
    Puppet::Node.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
