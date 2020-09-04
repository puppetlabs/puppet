require 'spec_helper'
require 'puppet/network/authconfig'

describe Puppet::Network::AuthConfig do
  it "accepts an auth provider class" do
    Puppet::Network::AuthConfig.authprovider_class = Object
  end
end
