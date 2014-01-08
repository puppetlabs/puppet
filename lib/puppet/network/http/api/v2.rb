class Puppet::Network::HTTP::API::V2
  def self.routes
    [Puppet::Network::HTTP::Route.get(
      %r{^/v2/environments$}, lambda { |req, res| raise Puppet::Network::HTTP::Handler::HTTPNotAuthorizedError, "You shall not pass!" })]
  end
end
