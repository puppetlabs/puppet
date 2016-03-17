#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/node'
require 'puppet/indirector/memory'
require 'puppet/indirector/facts/store_configs'

class Puppet::Node::Facts::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Node::Facts::StoreConfigs do
  after :all do
    Puppet::Node::Facts.indirection.reset_terminus_class
    Puppet::Node::Facts.indirection.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
