require 'puppet/network/client_request'
require 'puppet/network/authconfig'

module Puppet::Network
  module Authorization


    # Create our config object if necessary. If there's no configuration file
    # we install our defaults
    def authconfig
      @authconfig ||= Puppet::Network::AuthConfig.main

      @authconfig
    end

    # Verify that our client has access.
    def check_authorization(indirection, method, key, params)
      authconfig.check_authorization(indirection, method, key, params)
    end
  end
end

