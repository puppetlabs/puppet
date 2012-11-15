#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/node'
require 'puppet/indirector/memory'
require 'puppet/indirector/catalog/store_configs'

class Puppet::Resource::Catalog::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Resource::Catalog::StoreConfigs do
  after :each do
    Puppet::Resource::Catalog.indirection.reset_terminus_class
    Puppet::Resource::Catalog.indirection.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
