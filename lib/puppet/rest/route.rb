require 'uri'
require 'puppet/util/connection'

module Puppet::Rest
  class Route
    attr_reader :server

    # Create a Route containing information for querying the given API,
    # hosted at a server determined either by SRV service or by the
    # fallback server on the fallback port.
    # @param [String] api the path leading to the root of the API. Must
    #                 contain a trailing slash for proper endpoint path
    #                 construction
    # @param [Symbol] server_setting the setting to check for special
    #                 server configuration
    # @param [Symbol] port_setting the setting to check for speical
    #                  port configuration
    # @param [Symbol] srv_service the name of the service when using SRV
    #                 records
    def initialize(api:, server_setting: :server, port_setting: :masterport, srv_service: :puppet)
      @api = api
      @default_server = Puppet::Util::Connection.determine_server(server_setting)
      @default_port = Puppet::Util::Connection.determine_port(port_setting, server_setting)
      @srv_service = srv_service
    end

    # Select a server and port to create a base URL for the API specified by this
    # route. If the connection fails and SRV records are in use, the next suitable
    # server will be tried. If SRV records are not in use or no successful connection
    # could be made, fall back to the configured server and port for this API, taking
    # into account failover settings.
    # @parma [Puppet::Network::Resolver] dns_resolver the DNS resolver to use to check
    #                                    SRV records
    # @yield [URI] supply a base URL to make a request with
    # @raise [Puppet::Error] if connection to selected server and port fails, and SRV
    #                        records are not in use
    def with_base_url(dns_resolver)
      if @server && @port
        # First try connecting to the previously selected server and port.
        begin
          return yield(base_url)
        rescue SystemCallError => e
          if Puppet[:use_srv_records]
            Puppet.debug "Connection to cached server and port #{@server}:#{@port} failed, reselecting."
          else
            raise Puppet::Error, _("Connection to cached server and port %{server}:%{port} failed: %{message}") %
              { server: @server, port: @port, message: e.message }
          end
        end
      end

      if Puppet[:use_srv_records]
        dns_resolver.each_srv_record(Puppet[:srv_domain], @srv_service) do |srv_server, srv_port|
          # Try each of the servers for this service in weighted order
          # until a working one is found.
          begin
            @server = srv_server
            @port = srv_port
            return yield(base_url)
          rescue SystemCallError
            Puppet.debug "Connection to selected server and port #{@server}:#{@port} failed. Trying next cached SRV record."
            @server = nil
            @port = nil
          end
        end
      end

      # If not using SRV records, fall back to the defaults calculated above
      @server = @default_server
      @port = @default_port

      Puppet.debug "No more servers in SRV record, falling back to #{@server}:#{@port}" if Puppet[:use_srv_records]
      return yield(base_url)
    end

    private

    # Returns a URI built from the information stored by this route,
    # e.g. 'https://myserver.com:555/myapi/v1/'
    def base_url
      URI::HTTPS.build(host: @server, port: @port, path: @api)
    end
  end
end
