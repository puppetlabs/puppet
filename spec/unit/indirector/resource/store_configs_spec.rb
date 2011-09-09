#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/resource'
require 'puppet/indirector/memory'
require 'puppet/indirector/resource/store_configs'

class Puppet::Resource::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Resource::StoreConfigs do
  it_should_behave_like "a StoreConfigs terminus"
end
