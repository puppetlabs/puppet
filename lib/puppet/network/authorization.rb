require 'puppet/network/client_request'
require 'puppet/network/authconfig'
require 'puppet/network/auth_config_parser'

module Puppet::Network
  class AuthConfigLoader
    # Create our config object if necessary. If there's no configuration file
    # we install our defaults
    def self.authconfig
      @auth_config_file ||= Puppet::Util::WatchedFile.new(Puppet[:rest_authconfig])
      if (not @auth_config) or @auth_config_file.changed?
        begin
          @auth_config = Puppet::Network::AuthConfigParser.new_from_file(Puppet[:rest_authconfig]).parse
        rescue Errno::ENOENT, Errno::ENOTDIR
          @auth_config = Puppet::Network::AuthConfig.new
        end
      end

      @auth_config
    end
  end

  module Authorization
    def authconfig
      AuthConfigLoader.authconfig
    end

    # Verify that our client has access.
    def check_authorization(method, path, params)
      authconfig.check_authorization(method, path, params)
    end
  end
end

