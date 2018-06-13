require 'puppet/rest/route'

module Puppet::Rest
  module Routes

    ACCEPT_ENCODING = 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'

    def self.ca
      @ca ||= Route.new(api: '/puppet-ca/v1/',
                        default_server: Puppet[:ca_server],
                        default_port: Puppet[:ca_port],
                        srv_service: :ca)
    end

    # Make an HTTP request to fetch the named certificate, using the given
    # HTTP client.
    # @param [Puppet::Rest::Client] client the HTTP client to use to make the request
    # @param [String] name the name of the certificate to fetch
    # @raise [Puppet::Rest::ResponseError] if the response status is not OK
    # @return [String] the PEM-encoded certificate or certificate bundle
    def self.get_certificate(client, name)
      ca.with_base_url(client.dns_resolver) do |base_url|
        header = { 'Accept' => 'text/plain', 'Accept-Encoding' => ACCEPT_ENCODING }
        body = ''
        client.get("#{base_url}certificate/#{name}", header: header) do |chunk|
          body << chunk
        end
        Puppet.info _("Downloaded certificate for %{name} from %{server}") % { name: name, server: ca.server }
        body
      end
    end

    # Make an HTTP request to fetch the named crl, using the given
    # HTTP client. Accepts a block to stream responses to disk.
    # @param [Puppet::Rest::Client] client the HTTP client to use to make the request
    # @param [String] name the crl to fetch
    # @raise [Puppet::Rest::ResponseError] if the response status is not OK
    # @return nil
    def self.get_crls(client, name, &block)
      ca.with_base_url(client.dns_resolver) do |base_url|
        header = { 'Accept' => 'text/plain', 'Accept-Encoding' => ACCEPT_ENCODING }
        client.get("#{base_url}certificate_revocation_list/#{name}", header: header) do |chunk|
          block.call(chunk)
        end
        Puppet.debug _("Downloaded certificate revocation list for %{name} from %{server}") % { name: name, server: ca.server }
      end
    end

    # Make an HTTP request to send the named CSR, using the given
    # HTTP client.
    # @param [Puppet::Rest::Client] client the HTTP client to use to make the request
    # @param [String] csr_pem the contents of the CSR to sent to the CA
    # @param [String] name the name of the host whose CSR is being submitted
    # @rasies [Puppet::Rest::ResponseError] if the response status is not OK
    def self.put_certificate_request(client, csr_pem, name)
      ca.with_base_url(client.dns_resolver) do |base_url|
        header = { 'Accept' => 'text/plain',
                   'Accept-Encoding' => ACCEPT_ENCODING,
                   'Content-Type' => 'text/plain' }
        response = client.put("#{base_url}certificate_request/#{name}", body: csr_pem, header: header)
        if response.ok?
          Puppet.debug "Submitted certificate request to server."
        else
          raise response.to_exception
        end
      end
    end

    # Make an HTTP request to get the named CSR, using the given
    # HTTP client.
    # @param [Puppet::Rest::Client] client the HTTP client to use to make the request
    # @param [String] name the name of the host whose CSR is being queried
    # @rasies [Puppet::Rest::ResponseError] if the response status is not OK
    # @return [String] the PEM encoded certificate request
    def self.get_certificate_request(client, name)
      ca.with_base_url(client.dns_resolver) do |base_url|
        header = { 'Accept' => 'text/plain', 'Accept-Encoding' => ACCEPT_ENCODING }
        body = ''
        client.get("#{base_url}certificate_request/#{name}", header: header) do |chunk|
          body << chunk
        end
        Puppet.debug _("Downloaded existing certificate request for %{name} from %{server}") % { name: name, server: ca.server }
        body
      end
    end
  end
end
