require 'httpclient'

require 'puppet'
require 'puppet/rest/response'

module Puppet::Rest
  class Client
    # Create a new HTTP client for querying the given API.
    # @param [Puppet::Rest::Route] route data about the API being queried,
    #                              including the API name and server details.
    # @param [OpenSSL::X509::Store] ssl_store the SSL configuration for this client
    # @param [Integer] receive_timeout how long in seconds this client will wait
    #                  for a response after making a request
    # @param [HTTPClient] client the third-party HTTP client wrapped by this
    #                     class. This param is only used for testing.
    def initialize(route,
                   ssl_store: OpenSSL::X509::Store.new,
                   receive_timeout: Puppet.settings[:http_read_timeout],
                   client: HTTPClient.new(agent_name: nil,
                                          default_header: {
                                            'User-Agent' => Puppet.settings[:http_user_agent],
                                            'X-PUPPET-VERSION' => Puppet::PUPPETVERSION
                                          }))
      @client = client

      configure_client(ssl_store, route, receive_timeout)
    end

    # Configures the underlying HTTPClient
    # @param [OpentSSL::X509::Store] ssl_store the SSL configuration for this client
    # @param [Puppet::Rest::Route] route data about the API being queried
    # @param [Integer] timeout how long to wait for a response from the server once
    #                  a request has been made
    def configure_client(ssl_store, route, timeout)
      @client.tcp_keepalive = true
      @client.connect_timeout = Puppet.settings[:http_connect_timeout]
      @client.receive_timeout = timeout

      @client.cert_store = ssl_store

      server, port = route.select_server_and_port
      @client.base_url = "https://#{server}:#{port}#{route.api}/"

      if Puppet.settings[:http_debug]
        @client.debug_dev = $stderr
      end
    end
    private :configure_client

    def base_url
      @client.base_url
    end

    # Make a GET request to the specified endpoint with the specified params.
    # @param [String] endpoint the endpoint of the configured API to query
    # @param [Hash] query any URL params to add to send to the endpoint
    # @param [Hash] header any additional entries to add to the default header
    # @return [Puppet::Rest::Response] the response from the server
    def get(endpoint, query: nil, header: nil)
      response = @client.get(endpoint, query: query, header: header)
      Puppet::Rest::Response.new(response)
    end
  end
end
