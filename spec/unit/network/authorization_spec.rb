require 'spec_helper'
require 'puppet/network/authorization'

describe Puppet::Network::Authorization do
  it "accepts an auth config loader class" do
    Puppet::Network::Authorization.authconfigloader_class = Object
  end
end
