require 'httpclient'

require 'puppet'
require 'puppet/rest/response'
require 'puppet/rest/errors'

module Puppet::Rest
  class Client
    attr_reader :dns_resolver

    # Create a new HTTP client.
    # @param [Integer] receive_timeout how long in seconds this client will wait
    #                  for a response after making a request
    # @param [HTTPClient] client the third-party HTTP client wrapped by this
    #                     class. This param is only used for testing.
    def initialize(receive_timeout: Puppet[:http_read_timeout],
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

      @client.ssl_config.clear_cert_store
      ca_path = Puppet[:ssl_client_ca_auth] || Puppet[:localcacert]
      @client.ssl_config.verify_callback = Puppet::SSL::Validator::DefaultValidator.new(ca_path)

      if Puppet[:http_debug]
        @client.debug_dev = $stderr
      end

      @dns_resolver = Puppet::Network::Resolver.new
    end

    # In order to use this client to talk to a puppet master,
    # this method must be called with an appropriate context before making
    # a request.
    # For an unverified connection (for downloading the CA cert intially),
    # pass Puppet::Rest::SSLContext.verify_none.
    # For a verified connection, pass Puppet::Rest::Client::SSLContext.verify_peer
    # with a SSLStore that has been configured with th necesary certs and CRLs.
    # @param [Puppet::Rest::SSLContext] ssl_context an object specifying the desired
    #        verify mode and certificate configuration to use for connections created
    #        by this client.
    def configure_verify_mode(ssl_context)
      @client.ssl_config.cert_store = ssl_context.cert_store
      @client.ssl_config.verify_mode = ssl_context.verify_mode
    end

    # Make a GET request to the specified URL with the specified params.
    # @param [String] url the full path to query
    # @param [Hash] query any URL params to add to send to the endpoint
    # @param [Hash] header any additional entries to add to the default header
    # @yields [String] chunks of the response body
    # @raise [Puppet::Rest::ResponseError] if the response status is not OK
    def get(url, query: nil, header: nil, &block)
      make_request_with_cleanup do
        begin
          @client.get_content(url, { query: query, header: header }) do |chunk|
            block.call(chunk)
          end
        rescue HTTPClient::BadResponseError => e
          raise Puppet::Rest::ResponseError.new(e.message, Puppet::Rest::Response.new(e.res))
        end
      end
    end

    # Make a PUT request to the specified URL with the specified params.
    # @param [String] url the full path to query
    # @param [String/Hash] body the contents of the PUT request
    # @param [Hash] query any URL params to add to send to the endpoint
    # @param [Hash] header any additional entries to add to the default header
    # @return [Puppet::Rest::Response]
    def put(url, body:, query: nil, header: nil)
      make_request_with_cleanup do
        response = @client.put(url, body: body, query: query, header: header)
        Puppet::Rest::Response.new(response)
      end
    end

    private

    # If the request within the block of this function used an insecure connection,
    # reset the SSL state to ensure that it isn't used for any future requests.
    def make_request_with_cleanup(*args)
      yield(args)
    ensure
      reset_all if insecure?
    end

    # Reset the SSL configuration to VERIFY_PEER to ensure a secure
    # connection, and reset all existing connections to delete any
    # that were configured to be insecure.
    def reset_all
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @client.reset_all
    end

    def insecure?
      @client.ssl_config.verify_mode == OpenSSL::SSL::VERIFY_NONE
    end
  end
end
