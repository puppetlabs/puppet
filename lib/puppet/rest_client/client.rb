# frozen_string_literal: true
require 'httpclient'
require 'puppet'
require 'puppet/file_system'

module Puppet
  module Rest
    # TBD
    class Client
      def self.instance
        @@instance ||= new(Puppet.settings[:http_user_agent],
                           Puppet::PUPPETVERSION)
      end

      # Create an HTTP client that makes requests with a default header
      # @param [String] user_agent the User-Agent string for the default header
      # @param [String] version the version of puppet in use, for the default header
      def initialize(user_agent, version)
        @http = HTTPClient.new(
          agent_name: nil,
          default_header: {
            'User-Agent' => user_agent,
            'X-PUPPET-VERSION' => version
          }

        )

        # enable to see traffic on the wire
        #@http.debug_dev = $stderr

        @http.tcp_keepalive = true
        @http.connect_timeout = 10
        @http.receive_timeout = 60 * 60
        @http.request_filter << self
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

      def check_validation_mode
        ssl_config = @http.ssl_config

        # Is this expensive to do for every request? Probably not compared to the
        # shenanigans we're doing now
        if Puppet::FileSystem.exist?(Puppet.settings[:hostcert])
          ssl_config.clear_cert_store
          ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
          ssl_config.add_trust_ca(Puppet::FileSystem.expand_path(Puppet.settings[:localcacert]))
          ssl_config.set_client_cert_file(Puppet::FileSystem.expand_path(Puppet.settings[:hostcert]),
                                          Puppet::FileSystem.expand_path(Puppet.settings[:hostprivkey]))
          ssl_config.add_crl(Puppet::FileSystem.expand_path(Puppet.settings[:hostcrl]))
        else
          ssl_config.clear_cert_store
          ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      ### HTTP actions ###

      # @param [String] url full request URL
      def get(url, query, header)
        check_validation_mode
        @http.get(url, query, header)
      end
    end
  end
end
