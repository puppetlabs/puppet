# frozen_string_literal: true
require 'httpclient'
require 'puppet'
require 'puppet/file_system'
require 'puppet/rest_client/server_resolver'

module Puppet::Rest
  class Client

    attr_reader :server_resolver
    # Create an HTTP client that makes requests with a default header
    # @param [Integer] verify_mode how to secure the connection. Valid values are
    #                  OpenSSL::SSL::VERIFY_NONE and OpenSSL::SSL::VERIFY_PEER.
    # @param [Integer] timeout the timeout for recieving responses to requests made by this client
    def initialize(verify_mode: OpenSSL::SSL::VERIFY_PEER, usr_crl: true, timeout: 3600,
                   server_resolver: Puppet::Rest::ServerResolver.new)
      @http = HTTPClient.new(
        agent_name: nil,
        default_header: {
          'User-Agent' => Puppet.settings[:http_user_agent],
          'X-PUPPET-VERSION' => Puppet::PUPPETVERSION
        }
      )

      # enable to see traffic on the wire
      #@http.debug_dev = $stderr

      @http.tcp_keepalive = true
      @http.connect_timeout = 10
      @http.receive_timeout = timeout
      @http.request_filter << self

      setup_ssl(verify_mode, true)

      @server_resolver = server_resolver
    end

    def setup_ssl(verify_mode, use_crl)
      ssl_config = @http.ssl_config
      ssl_config.clear_cert_store
      ssl_config.verify_mode = verify_mode

      if verify_mode == OpenSSL::SSL::VERIFY_PEER
        configure_ssl_store
      end
    end

    def configure_ssl_store(use_crl)
      if Puppet::FileSystem.exist?(Puppet.settings[:hostcert])
        ssl_config.add_trust_ca(Puppet::FileSystem.expand_path(Puppet.settings[:localcacert]))
        ssl_config.set_client_cert_file(Puppet::FileSystem.expand_path(Puppet.settings[:hostcert]),
                                        Puppet::FileSystem.expand_path(Puppet.settings[:hostprivkey]))

        if use_crl
          ssl_config.add_crl(Puppet::FileSystem.expand_path(Puppet.settings[:hostcrl]))
        end
      else
        Puppet.error _("No certs found, can't use secure connection.")
      end
    end

    def disconnect
      @http.reset_all
    end

    def filter_request(req)
      Puppet.debug _("Connecting to %{uri} (%{method})") % {uri: req.header.request_uri, method: req.header.request_method }
    end

    def filter_response(_req, res)
      Puppet.debug _("Done %{status} %{reason}\n\n") % { status: res.status, reason: res.reason }
    end

    ### HTTP actions ###

    # @param [String] url full request URL
    def get(url, query, header)
      @http.get(url, query, header)
    end
  end
end
