require 'puppet'
require 'puppet/rest_client/server_resolution'

module Puppet
  module Routes
    def self.ca
     {
       :server => Puppet.settings[:ca_server],
       :port => Puppet.settings[:ca_port],
       :srv_service => :ca,
       :base_url => "/puppet-ca/v1"
     }
    end

    def self.certificate(name)
      server, port = Puppet::Rest::Resolution.select_server_and_port(
        srv_service: ca[:srv_service],
        default_server: ca[:server],
        default_port: ca[:port])

      "https://#{server}:#{port}#{ca[:base_url]}/certificate/#{name}"
    end
  end
end

