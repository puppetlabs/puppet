require 'puppet/rest/route'

module Puppet::Rest
  module Routes
    ACCEPT_ENCODING = 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'

    def self.ca
      Route.new(api: '/puppet-ca/v1/', default_server: Puppet[:ca_server], default_port: Puppet[:ca_port])
    end

    # Make an HTTP request to fetch the named certificate, using the given
    # HTTP client.
    # @param [Puppet::Rest::Client] client the HTTP client to use to make the request
    # @param [String] name the name of the certificate to fetch
    # @raise [Puppet::Rest::ResponseError] if the response status is not OK
    # @return [String] the PEM-encoded certificate or certificate bundle
    def self.get_certificate(client, name)
      header = { 'Accept' => 'text/plain', 'accept-encoding' => ACCEPT_ENCODING }
      body = ''
      client.get("certificate/#{name}", header: header) do |chunk|
        body << chunk
      end
      body
    end
  end
end
