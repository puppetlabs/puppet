# frozen_string_literal: true
require 'httpclient'

module Puppet
  module Rest
    # TBD
    class Client
      # Create an HTTP client that makes requests with a default header
      # @param [String] user_agent the User-Agent string for the default header
      # @param [String] version the version of puppet in use, for the default header
      def initialize(user_agent, version)
        @http = HTTPClient.new(
          # we don't always connect to the same server and port,
          # maybe we shouldn't set any default here
          agent_name: nil,
          default_header: {
            'User-Agent': user_agent,
            'X-PUPPET-VERSION': version
          }
        )

        # enable to see traffic on the wire
        # @http.debug_dev = $stderr

        @http.tcp_keepalive = true
        @http.connect_timeout = 10
        @http.receive_timeout = 60 * 60
        @http.request_filter << self
      end

      def disconnect
        @http.reset_all
      end

      def filter_request(req)
        warn "Connecting to #{req.header.request_uri} (#{req.header.request_method})"
      end

      def filter_response(_req, res)
        warn "Done #{res.status} #{res.reason}\n\n"
      end

      ### HTTP actions ###

      # @param [String] url full request URL
      def get(url, query, header)
        @http.get(url, query, header)
      end
    end
  end
end
