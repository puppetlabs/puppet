module Puppet::Network::HTTP::API::V2
  require 'puppet/network/http/api/v2/environments'
  require 'puppet/network/http/api/v2/authorization'

  NOT_FOUND = Puppet::Network::HTTP::Route.
    path(/.*/).
    any(lambda { |req, res| raise Puppet::Network::HTTP::Handler::HTTPNotFoundError, req.path })

  def self.routes
    [Puppet::Network::HTTP::Route.path(%r{^/v2\.0}).get(Authorization.new).chain(Environments::ROUTE, NOT_FOUND)]
  end
end
