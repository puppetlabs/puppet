module Puppet::Rest
  class Route
    attr_reader :api, :srv_service, :default_server, :default_port

    # Create a Route containing information for querying the given API,
    # hosted at a server determined either by SRV service or by the
    # fallback server on the fallback port.
    def initialize(api:, srv_service:, default_server:, default_port:)
      @api = api
      @srv_service = srv_service
      @default_server= default_server
      @default_port = default_port
    end
  end
end
