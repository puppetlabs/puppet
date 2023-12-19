# frozen_string_literal: true

module Puppet
  class Network::AuthConfig
    def self.authprovider_class=(_)
      # legacy auth is not supported, ignore
    end
  end
end
