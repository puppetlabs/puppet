require 'httpclient'

require 'puppet'
require 'puppet/rest/response'
require 'puppet/rest/errors'

module Puppet::Rest
  class Client
    attr_reader :dns_resolver

    # Create a new HTTP client for querying the given API.
    # @param [OpenSSL::X509::Store] ssl_store the SSL configuration for this client
    # @param [Integer] receive_timeout how long in seconds this client will wait
    #                  for a response after making a request
    # @param [HTTPClient] client the third-party HTTP client wrapped by this
    #                     class. This param is only used for testing.
    def initialize(ssl_store: OpenSSL::X509::Store.new,
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

      @client.ssl_config.cert_store = ssl_store

      configure_verify_mode(@client.ssl_config)

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

    private

    # Checks for SSL certificates on disk and sets VERIFY_PEER
    # if they are found. Otherwise, sets VERIFY_NONE.
    def configure_verify_mode(ssl_config)
      # Either the path to an external CA or to our CA cert from the Puppet master
      # TODO We may be able to consolidate this with the current intermediate CA work?
      ca_path = Puppet[:ssl_client_ca_auth] || Puppet[:localcacert]

      if ssl_certificates_are_present?(ca_path)
        ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ssl_config.add_trust_ca(ca_path)
        ssl_config.verify_callback = Puppet::SSL::Validator::DefaultValidator.new(ca_path)
        ssl_config.set_client_cert_file(Puppet[:hostcert], Puppet[:hostprivkey])
      else
        ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    def ssl_certificates_are_present?(ca_path)
      Puppet::FileSystem.exist?(Puppet[:hostcert]) && Puppet::FileSystem.exist?(ca_path)
    end
  end
end
