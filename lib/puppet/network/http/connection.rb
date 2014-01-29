require 'net/https'
require 'puppet/ssl/host'
require 'puppet/ssl/configuration'
require 'puppet/ssl/validator'
require 'puppet/network/authentication'
require 'uri'

module Puppet::Network::HTTP

  # This will be raised if too many redirects happen for a given HTTP request
  class RedirectionLimitExceededException < Puppet::Error ; end

  # This class provides simple methods for issuing various types of HTTP
  # requests.  It's interface is intended to mirror Ruby's Net::HTTP
  # object, but it provides a few important bits of additional
  # functionality.  Notably:
  #
  # * Any HTTPS requests made using this class will use Puppet's SSL
  #   certificate configuration for their authentication, and
  # * Provides some useful error handling for any SSL errors that occur
  #   during a request.
  class Connection
    include Puppet::Network::Authentication

    OPTION_DEFAULTS = {
      :use_ssl => true,
      :verify => nil,
      :redirect_limit => 10
    }

    @@openssl_initialized = false

    # Creates a new HTTP client connection to `host`:`port`.
    # @param host [String] the host to which this client will connect to
    # @param port [Fixnum] the port to which this client will connect to
    # @param options [Hash] options influencing the properties of the created connection,
    #   the following options are recognized:
    #     :use_ssl [Boolean] true to connect with SSL, false otherwise, defaults to true
    #     :verify [#setup_connection] An object that will configure any verification to do on the connection
    #     :redirect_limit [Fixnum] the number of allowed redirections, defaults to 10
    #   passing any other option in the options hash results in a Puppet::Error exception
    # @note the HTTP connection itself happens lazily only when {#request}, or one of the {#get}, {#post}, {#delete}, {#head} or {#put} is called
    # @api private
    def initialize(host, port, options = {})
      @host = host
      @port = port

      unknown_options = options.keys - OPTION_DEFAULTS.keys
      raise Puppet::Error, "Unrecognized option(s): #{unknown_options.map(&:inspect).sort.join(', ')}" unless unknown_options.empty?

      options = OPTION_DEFAULTS.merge(options)
      @use_ssl = options[:use_ssl]
      @verify = options[:verify]
      @redirect_limit = options[:redirect_limit]
    end

    def get(*args)
      request(:get, *args)
    end

    def post(*args)
      request(:post, *args)
    end

    def head(*args)
      request(:head, *args)
    end

    def delete(*args)
      request(:delete, *args)
    end

    def put(*args)
      request(:put, *args)
    end

    def request(method, *args)
      current_args = args.dup
      @redirect_limit.times do |redirection|
        response = execute_request(method, *args)
        return response unless [301, 302, 307].include?(response.code.to_i)

        # handle the redirection
        location = URI.parse(response['location'])
        @connection = initialize_connection(location.host, location.port, location.scheme == 'https')

        # update to the current request path
        current_args = [location.path] + current_args.drop(1)
        # and try again...
      end
      raise RedirectionLimitExceededException, "Too many HTTP redirections for #{@host}:#{@port}"
    end

    # TODO: These are proxies for the Net::HTTP#request_* methods, which are
    # almost the same as the "get", "post", etc. methods that we've ported above,
    # but they are able to accept a code block and will yield to it.  For now
    # we're not funneling these proxy implementations through our #request
    # method above, so they will not inherit the same error handling.  In the
    # future we may want to refactor these so that they are funneled through
    # that method and do inherit the error handling.
    def request_get(*args, &block)
      connection.request_get(*args, &block)
    end

    def request_head(*args, &block)
      connection.request_head(*args, &block)
    end

    def request_post(*args, &block)
      connection.request_post(*args, &block)
    end
    # end of Net::HTTP#request_* proxies

    def address
      connection.address
    end

    def port
      connection.port
    end

    def use_ssl?
      connection.use_ssl?
    end

    private

    def connection
      @connection || initialize_connection(@host, @port, @use_ssl)
    end

    def execute_request(method, *args)
      response = connection.send(method, *args)

      # Check the peer certs and warn if they're nearing expiration.
      warn_if_near_expiration(*@verify.peer_certs)

      response
    rescue OpenSSL::SSL::SSLError => error
      if error.message.include? "certificate verify failed"
        msg = error.message
        msg << ": [" + @verify.verify_errors.join('; ') + "]"
        raise Puppet::Error, msg
      elsif error.message =~ /hostname (\w+ )?not match/
        leaf_ssl_cert = @verify.peer_certs.last

        valid_certnames = [leaf_ssl_cert.name, *leaf_ssl_cert.subject_alt_names].uniq
        msg = valid_certnames.length > 1 ? "one of #{valid_certnames.join(', ')}" : valid_certnames.first

        raise Puppet::Error, "Server hostname '#{connection.address}' did not match server certificate; expected #{msg}"
      else
        raise
      end
    end

    def initialize_connection(host, port, use_ssl)
      args = [host, port]
      if Puppet[:http_proxy_host] == "none"
        args << nil << nil
      else
        args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
      end

      @connection = create_connection(*args)

      # Pop open the http client a little; older versions of Net::HTTP(s) didn't
      # give us a reader for ca_file... Grr...
      class << @connection; attr_accessor :ca_file; end

      @connection.use_ssl = use_ssl
      # Use configured timeout (#1176)
      @connection.read_timeout = Puppet[:configtimeout]
      @connection.open_timeout = Puppet[:configtimeout]

      cert_setup

      @connection
    end

    # Use cert information from a Puppet client to set up the http object.
    def cert_setup
      # PUP-1411, make sure that openssl is initialized before we try to connect
      if ! @@openssl_initialized
        OpenSSL::SSL::SSLContext.new
        @@openssl_initialized = true
      end

      @verify.setup_connection(@connection)
    end

    # This method largely exists for testing purposes, so that we can
    # mock the actual HTTP connection.
    def create_connection(*args)
      Net::HTTP.new(*args)
    end
  end
end
