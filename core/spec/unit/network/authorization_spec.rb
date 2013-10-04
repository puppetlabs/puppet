#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/authorization'

describe Puppet::Network::Authorization do
  class AuthTest
    include Puppet::Network::Authorization
  end

  subject { AuthTest.new }

  describe "when creating an authconfig object" do
    it "creates default ACL entries if no file has been read" do
      # Other tests may have created an authconfig, so we have to undo that.
      Puppet::Network::AuthConfigLoader.instance_variable_set(:@auth_config, nil)
      Puppet::Network::AuthConfigLoader.instance_variable_set(:@auth_config_file, nil)

      Puppet::Network::AuthConfigParser.expects(:new_from_file).raises Errno::ENOENT
      Puppet::Network::AuthConfig.any_instance.expects(:insert_default_acl)

      subject.authconfig
    end
  end
end
