#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/authorization'

describe Puppet::Network::Authorization do
  class AuthTest
    include Puppet::Network::Authorization
  end

  subject { AuthTest.new }

  describe "when creating an authconfig object" do
    before :each do
      # Other tests may have created an authconfig, so we have to undo that.
      @orig_auth_config = Puppet::Network::AuthConfigLoader.instance_variable_get(:@auth_config)
      @orig_auth_config_file = Puppet::Network::AuthConfigLoader.instance_variable_get(:@auth_config_file)

      Puppet::Network::AuthConfigLoader.instance_variable_set(:@auth_config, nil)
      Puppet::Network::AuthConfigLoader.instance_variable_set(:@auth_config_file, nil)
    end

    after :each do
      Puppet::Network::AuthConfigLoader.instance_variable_set(:@auth_config, @orig_auth_config)
      Puppet::Network::AuthConfigLoader.instance_variable_set(:@auth_config_file, @orig_auth_config_file)
    end

    it "creates default ACL entries if no file has been read" do
      Puppet::Network::AuthConfigParser.expects(:new_from_file).raises Errno::ENOENT
      Puppet::Network::AuthConfig.any_instance.expects(:insert_default_acl)

      subject.authconfig
    end
  end
end
