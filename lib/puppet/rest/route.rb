module Puppet::Rest
  class Route
    attr_reader :api, :srv_service, :default_server, :default_port

    attr_reader :server, :port

    # Create a Route containing information for querying the given API,
    # hosted at a server determined either by SRV service or by the
    # fallback server on the fallback port.
    def initialize(api:, srv_service:, default_server:, default_port:)
      @api = api
      @srv_service = srv_service
      @default_server= default_server
      @default_port = default_port
    end

    # Return the appropriate server and port for this route
    # @return [String, Integer] the server and port to use for the request
    def select_server_and_port
      unless @server && @port
        if Puppet.settings[:use_srv_records]
          Puppet::Network::Resolver.each_srv_record(Puppet.settings[:srv_domain], srv_service) do |srv_server, srv_port|
            @server = srv_server
            @port = srv_port
          end
        else
          # Fall back to the default server, taking into account HA settings
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

          if Puppet.settings[:use_srv_records]
            Puppet.debug("No more servers left, falling back to #{server}:#{port}")
          end
        end
      end
      [@server, @port]
    end
  end
end
