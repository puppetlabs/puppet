class Puppet::Network::HTTP::API::V2::Environments
  ROUTE = Puppet::Network::HTTP::Route.path(%r{^/environments$}).get(
      lambda { |req, res| raise Puppet::Network::HTTP::Error::HTTPNotAuthorizedError, "You shall not pass!" })
end
