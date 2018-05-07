require 'URI'

module Puppet::Rest
  class Route
    attr_reader :api, :default_server, :default_port

    attr_reader :server, :port

    # Create a Route containing information for querying the given API,
    # hosted at a server determined either by SRV service or by the
    # fallback server on the fallback port.
    # @param [String] api the path leading to the root of the API. Must
    #                 contain a trailing slash for proper endpoint path
    #                 construction
    # @param [String] default_server the fqdn of the fallback server
    # @param [Integer] port the fallback port
    def initialize(api:, default_server:, default_port:)
      @api = api
      @default_server= default_server
      @default_port = default_port
    end

    # Returns a URI built from the information stored by this route,
    # e.g. 'https://myserver.com:555/myapi/v1/'
    def uri
      server, port = select_server_and_port
      URI::HTTPS.build(host: server, port: port, path: api)
    end

    # Return the appropriate server and port for this route
    # @return [String, Integer] the server and port to use for the request
    def select_server_and_port
      unless @server && @port
        if default_server && default_port
          @server = default_server
          @port = default_port
          return default_server, default_port
        end

        bound_server = Puppet.lookup(:server) do
          if primary_server = Puppet.settings[:server_list][0]
            primary_server[0]
          else
            Puppet.settings[:server]
          end
        end

        bound_port = Puppet.lookup(:serverport) do
          if primary_server = Puppet.settings[:server_list][0]
            primary_server[1]
          else
            Puppet.settings[:masterport]
          end
        end

        @server = default_server || bound_server
        @port = default_port || bound_port
      end
      [@server, @port]
    end
  end
end
