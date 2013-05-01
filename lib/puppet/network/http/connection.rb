require 'net/https'
require 'puppet/ssl/host'
require 'puppet/ssl/configuration'
require 'puppet/ssl/validator'
require 'puppet/network/authentication'

module Puppet::Network::HTTP

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

    def initialize(host, port, use_ssl = true)
      @host = host
      @port = port
      @use_ssl = use_ssl
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
      ssl_validator = Puppet::SSL::Validator.new(:ssl_configuration => ssl_configuration)
      # Perform our own validation of the SSL connection in addition to OpenSSL
      ssl_validator.register_verify_callback(connection)
      response = connection.send(method, *args)
      # Check the peer certs and warn if they're nearing expiration.
      warn_if_near_expiration(*ssl_validator.peer_certs)

      response
    rescue OpenSSL::SSL::SSLError => error
      if error.message.include? "certificate verify failed"
        msg = error.message
        msg << ": [" + ssl_validator.verify_errors.join('; ') + "]"
        raise Puppet::Error, msg
      elsif error.message =~ /hostname (\w+ )?not match/
        leaf_ssl_cert = ssl_validator.peer_certs.last

        valid_certnames = [leaf_ssl_cert.name, *leaf_ssl_cert.subject_alt_names].uniq
        msg = valid_certnames.length > 1 ? "one of #{valid_certnames.join(', ')}" : valid_certnames.first

        raise Puppet::Error, "Server hostname '#{connection.address}' did not match server certificate; expected #{msg}"
      else
        raise
      end
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
      @connection || initialize_connection
    end

    def initialize_connection
      args = [@host, @port]
      if Puppet[:http_proxy_host] == "none"
        args << nil << nil
      else
        args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
      end

      @connection = create_connection(*args)

      # Pop open the http client a little; older versions of Net::HTTP(s) didn't
      # give us a reader for ca_file... Grr...
      class << @connection; attr_accessor :ca_file; end

      @connection.use_ssl = @use_ssl
      # Use configured timeout (#1176)
      @connection.read_timeout = Puppet[:configtimeout]
      @connection.open_timeout = Puppet[:configtimeout]

      cert_setup

      @connection
    end

    # Use cert information from a Puppet client to set up the http object.
    def cert_setup
      if FileTest.exist?(Puppet[:hostcert]) and FileTest.exist?(ssl_configuration.ca_auth_file)
        @connection.cert_store  = ssl_host.ssl_store
        @connection.ca_file     = ssl_configuration.ca_auth_file
        @connection.cert        = ssl_host.certificate.content
        @connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
        @connection.key         = ssl_host.key.content
      else
        # We don't have the local certificates, so we don't do any verification
        # or setup at this early stage.  REVISIT: Shouldn't we supply the local
        # certificate details if we have them?  The original code didn't.
        # --daniel 2012-06-03

        # Ruby 1.8 defaulted to this, but 1.9 defaults to peer verify,
        # and we almost always talk to a dedicated, not-standard CA that
        # isn't trusted out of the box.  This forces the expected state.
        @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    # This method largely exists for testing purposes, so that we can
    # mock the actual HTTP connection.
    def create_connection(*args)
      Net::HTTP.new(*args)
    end

    # Use the global localhost instance.
    def ssl_host
      Puppet::SSL::Host.localhost
    end

    def ssl_configuration
      @ssl_configuration ||= Puppet::SSL::Configuration.new(
          Puppet[:localcacert],
          :ca_chain_file => Puppet[:ssl_client_ca_chain],
          :ca_auth_file  => Puppet[:ssl_client_ca_auth]
      )
    end
  end
end
