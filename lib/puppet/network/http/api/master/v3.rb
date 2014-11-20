class Puppet::Network::HTTP::API::Master::V3
  require 'puppet/network/http/api/master/v3/authorization'
  require 'puppet/network/http/api/master/v3/environments'
  require 'puppet/network/http/api/master/v3/environment'
  require 'puppet/network/http/api/indirected_routes'

  AUTHZ = Authorization.new

  INDIRECTED = Puppet::Network::HTTP::Route.
      path(/.*/).
      any(Puppet::Network::HTTP::API::IndirectedRoutes.new)

  ENVIRONMENTS = Puppet::Network::HTTP::Route.
      path(%r{^/environments$}).get(AUTHZ.wrap do
    Environments.new(Puppet.lookup(:environments))
  end)

  ENVIRONMENT = Puppet::Network::HTTP::Route.
      path(%r{/environment/[^/]+$}).get(AUTHZ.wrap do
    Environment.new
  end)

  def self.routes
    Puppet::Network::HTTP::Route.path(%r{v3}).
        any.
        chain(ENVIRONMENTS, ENVIRONMENT, INDIRECTED)
  end
end
