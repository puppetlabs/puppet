require 'puppet'
require 'puppet/rest_client/server_resolution'

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

    def self.certificate(name)
      server, port = Puppet::Rest::Resolution.select_server_and_port(
        srv_service: ca[:srv_service],
        default_server: ca[:server],
        default_port: ca[:port])

      "https://#{server}:#{port}#{ca[:base_url]}/certificate/#{name}"
    end

    def self.get_certificate(name)
      Puppet::Rest::Client.instance.get(certificate(name),
                                        { environment: Puppet.lookup(:current_environment).name },
                                        { Accept: 'text/plain',
                                          'accept-encoding' => ACCEPT_ENCODING })
    end
  end
end

