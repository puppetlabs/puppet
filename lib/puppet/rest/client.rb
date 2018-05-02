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

    # Create a new HTTP client for querying the given API.
    # @param [Puppet::Rest::Route] route data about the API being queried,
    #                              including the API name and server details.
    # @param [OpenSSL::X509::Store] ssl_store the SSL configuration for this client
    # @param [Integer] receive_timeout how long in seconds this client will wait
    #                  for a response after making a request
    # @param [HTTPClient] client the third-party HTTP client wrapped by this
    #                     class. This param is only used for testing.
    # @param [Puppet::Rest::ServerResolver] server_resolver the object responsible
    #                                       for finding the best available server
    #                                       given the data in `route`. This param
    #                                       is only used for testing.
    def initialize(route,
                   ssl_store: OpenSSL::X509::Store.new,
                   receive_timeout: 3600,
                   client: Puppet::Rest::Client.default_client,
                   server_resolver: Puppet::Rest::ServerResolver.new)
      @client = client

      @server_resolver = server_resolver
      configure_client(ssl_store, route, receive_timeout)
    end

    # Configures the underlying HTTPClient
    # @param [OpentSSL::X509::Store] ssl_store the SSL configuration for this client
    # @param [Puppet::Rest::Route] route data about the API being queried
    # @param [Integer] timeout how long to wait for a response from the server once
    #                  a request has been made
    def configure_client(ssl_store, route, timeout)
      @client.tcp_keepalive = true
      @client.connect_timeout = 10
      @client.receive_timeout = timeout
      # `request_filter` is a list of objects implementing the `filter_request` and
      # `filter_response` methods, which get called during request processing.
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
    private :server_and_port

    # Make a GET request to the specified endpoint with the specified params.
    # @param [String] endpoint the endpoint of the configured API to query
    # @param [Hash] query any URL params to add to send to the endpoint
    # @param [Hash] header any additional entries to add to the default header
    # @return [Puppet::Rest::Response] the response from the server
    def get(endpoint, query: nil, header: nil)
      response = @client.get(endpoint, query: query, header: header)
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
