require 'httpclient'

require 'puppet'
require 'puppet/rest/response'
require 'puppet/rest/errors'

module Puppet::Rest
  class Client
    attr_reader :dns_resolver

    # Create a new HTTP client for querying the given API.
    # @param [Puppet::Rest::SSLContext] ssl_context the SSL configuration for this client
    # @param [Integer] receive_timeout how long in seconds this client will wait
    #                  for a response after making a request
    # @param [HTTPClient] client the third-party HTTP client wrapped by this
    #                     class. This param is only used for testing.
    def initialize(ssl_context:,
                   receive_timeout: Puppet[:http_read_timeout],
                   client: HTTPClient.new(agent_name: nil,
                                          default_header: {
                                            'User-Agent' => Puppet[:http_user_agent],
                                            'X-PUPPET-VERSION' => Puppet::PUPPETVERSION
                                          }))
      @client = client
      @client.tcp_keepalive = true
      @client.connect_timeout = Puppet[:http_connect_timeout]
      @client.receive_timeout = receive_timeout
      @client.transparent_gzip_decompression = true

      if Puppet[:http_debug]
        @client.debug_dev = $stderr
      end

      configure_verify_mode(ssl_context)

      @dns_resolver = Puppet::Network::Resolver.new
    end

    # Make a GET request to the specified URL with the specified params.
    # @param [String] url the full path to query
    # @param [Hash] query any URL params to add to send to the endpoint
    # @param [Hash] header any additional entries to add to the default header
    # @yields [String] chunks of the response body
    # @raise [Puppet::Rest::ResponseError] if the response status is not OK
    def get(url, query: nil, header: nil, &block)
      begin
        @client.get_content(url, { query: query, header: header }) do |chunk|
          block.call(chunk)
        end
      rescue HTTPClient::BadResponseError => e
        raise Puppet::Rest::ResponseError.new(e.message, Puppet::Rest::Response.new(e.res))
      end
    end

    # Make a PUT request to the specified URL with the specified params.
    # @param [String] url the full path to query
    # @param [String/Hash] body the contents of the PUT request
    # @param [Hash] query any URL params to add to send to the endpoint
    # @param [Hash] header any additional entries to add to the default header
    # @return [Puppet::Rest::Response]
    def put(url, body:, query: nil, header: nil)
      response = @client.put(url, body: body, query: query, header: header)
      Puppet::Rest::Response.new(response)
    end

    private

    def configure_verify_mode(ssl_context)
      ca_path = Puppet[:ssl_client_ca_auth] || Puppet[:localcacert]
      @client.ssl_config.verify_callback = Puppet::SSL::Validator::DefaultValidator.new(ca_path)
      @client.ssl_config.cert_store = ssl_context.cert_store
      @client.ssl_config.verify_mode = ssl_context.verify_mode
    end
  end
end
