require 'httpclient'

module Puppet::Rest
  class Client
    def self.default_client
      HTTPClient.new(
        agent_name: nil,
        default_header: {
          'User-Agent' => Puppet.settings[:http_user_agent],
          'X-PUPPET-VERSION' => Puppet::PUPPETVERSION
        })
    end

    def initialize(client: Puppet::Rest::Client.default_client, ssl_store: OpenSSL::X509::Store.new,
                   receive_timeout: 3600)
      @client = client
      configure_client(ssl_store, receive_timeout)
    end

    def configure_client(ssl_store, timeout)
      @client.tcp_keepalive = true
      @client.connect_timeout = 10
      @client.receive_timeout = timeout
      @client.request_filter << self

      @client.cert_store = ssl_store
    end
    private :configure_client

    def get(url, query: nil, header: nil)
      @client.get(url, query: query, header: header)
    end

    # Called by the HTTPClient library while processing a request.
    # For debugging.
    def filter_request(req)
      Puppet.debug _("Connecting to %{uri} (%{method})") % {uri: req.header.request_uri, method: req.header.request_method }
    end

    # Called by the HTTPClient library upon receiving a response.
    # For debugging.
    def filter_response(_req, res)
      Puppet.debug _("Done %{status} %{reason}\n\n") % { status: res.status, reason: res.reason }
    end
  end
end
