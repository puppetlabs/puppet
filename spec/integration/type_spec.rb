#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/type'

describe Puppet::Type do
  it "should not lose its provider list when it is reloaded" do
    type = Puppet::Type.newtype(:integration_test) do
      newparam(:name) {}
    end

    provider = type.provide(:myprovider) {}

    # reload it
    type = Puppet::Type.newtype(:integration_test) do
      newparam(:name) {}
    end

    type.provider(:myprovider).should equal(provider)
  end

  it "should not lose its provider parameter when it is reloaded" do
    type = Puppet::Type.newtype(:reload_test_type)

    provider = type.provide(:test_provider)

    # reload it
    type = Puppet::Type.newtype(:reload_test_type)

    type.parameters.should include(:provider)
  end
end
