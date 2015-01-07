require 'puppet/network/http/api/indirected_routes'
class Puppet::Network::HTTP::API::CA::V1

  INDIRECTED = Puppet::Network::HTTP::Route.
    path(/.*/).
    any(Puppet::Network::HTTP::API::IndirectedRoutes.new)

  def self.routes
    Puppet::Network::HTTP::Route.path(%r{v1}).any.chain(INDIRECTED)
  end
end
