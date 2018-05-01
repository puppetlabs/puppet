require 'puppet'
require 'puppet/rest_client/client'

module Puppet::Rest
  module Routes

    ACCEPT_ENCODING = "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"

    def self.ca
     {
       :server => Puppet.settings[:ca_server],
       :port => Puppet.settings[:ca_port],
       :srv_service => :ca,
       :base_url => "/puppet-ca/v1"
     }
    end

    def self.get_certificate(client, name)
      # We are attempting to download certificates because we don't have them
      # on disk yet, so we need to use an insecure connection
      server, port = client.resolver.select_server_and_port(
                              srv_service: ca[:srv_service],
                              default_server: ca[:server],
                              default_port: ca[:port])

      client.get("https://#{server}:#{port}#{ca[:base_url]}/certificate/#{name}",
                 { environment: Puppet.lookup(:current_environment).name },
                 { Accept: 'text/plain',
                   'accept-encoding' => ACCEPT_ENCODING })
    end
  end
end

