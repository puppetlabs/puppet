require 'httpclient'

require 'puppet'
require 'puppet/rest/response'
require 'puppet/rest/server_resolver'

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

    attr_reader :base_url

    def initialize(route,
                   client: Puppet::Rest::Client.default_client,
                   ssl_store: OpenSSL::X509::Store.new,
                   server_resolver: Puppet::Rest::ServerResolver.new,
                   receive_timeout: 3600)
      @client = client

      @server_resolver = server_resolver
      configure_client(ssl_store, route, receive_timeout)
    end

    def configure_client(ssl_store, route, timeout)
      @client.tcp_keepalive = true
      @client.connect_timeout = 10
      @client.receive_timeout = timeout
      @client.request_filter << self

      @client.cert_store = ssl_store

      server, port = server_and_port(route)
      @base_url = "https://#{server}:#{port}#{route.api}"
      @client.base_url = base_url
    end
    private :configure_client

    # Returns the server and port to use for requests made by this client, given the
    # specified settings. The results are cached once they have been found.
    # @param [Puppet::Rest::Route] route data about the server and API we are querying
    # @return [String, Integer] the server and port to use for the request
    def server_and_port(route)
      @server_resolver.select_server_and_port(srv_service: route.srv_service,
                                              default_server: route.default_server,
                                              default_port: route.default_port)
    end

    def get(url, query: nil, header: nil)
      response = @client.get(url, query: query, header: header)
      Puppet::Rest::Response.new(response)
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
