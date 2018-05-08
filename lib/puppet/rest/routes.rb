require 'puppet/rest/route'

module Puppet::Rest
  module Routes
    ACCEPT_ENCODING = 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'

    def self.ca
      Route.new(api: '/puppet-ca/v1/', default_server: Puppet[:ca_server], default_port: Puppet[:ca_port])
    end

    def self.get_certificate(client, name)
      client.get("certificate/#{name}",
                 header: { 'Accept' => 'text/plain',
                           'accept-encoding' => ACCEPT_ENCODING })
    end
  end
end
