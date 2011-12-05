#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/node'
require 'puppet/indirector/memory'
require 'puppet/indirector/catalog/store_configs'

class Puppet::Resource::Catalog::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Resource::Catalog::StoreConfigs do
  after :each do
    Puppet::Resource::Catalog.terminus_class = nil
    Puppet::Resource::Catalog.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
