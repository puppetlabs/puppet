#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/resource'
require 'puppet/indirector/memory'
require 'puppet/indirector/resource/store_configs'

class Puppet::Resource::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Resource::StoreConfigs do
  it_should_behave_like "a StoreConfigs terminus"

  before :each do
    Puppet[:storeconfigs] = true
    Puppet[:storeconfigs_backend] = "store_configs_testing"
  end

  it "is deprecated on the network, but still allows requests" do
    Puppet.expects(:deprecation_warning)

    expect(Puppet::Resource::StoreConfigs.new.allow_remote_requests?).to eq(true)
  end
end
