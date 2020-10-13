class Puppet::Network::HTTP::API::Master::V3
  require 'puppet/network/http/api/master/v3/environments'
  require 'puppet/network/http/api/indirected_routes'

  def self.wrap(&block)
    lambda do |request, response|
      Puppet::Network::Authorization.check_external_authorization(request.method, request.path)

      block.call.call(request, response)
    end
  end

  INDIRECTED = Puppet::Network::HTTP::Route.
      path(/.*/).
      any(wrap { Puppet::Network::HTTP::API::IndirectedRoutes.new } )

  ENVIRONMENTS = Puppet::Network::HTTP::Route.
      path(%r{^/environments$}).
      get(wrap { Environments.new(Puppet.lookup(:environments)) } )

  def self.routes
    Puppet::Network::HTTP::Route.path(%r{v3}).
        any.
        chain(ENVIRONMENTS, INDIRECTED)
  end
end
