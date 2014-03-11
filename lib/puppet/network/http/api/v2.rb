module Puppet::Network::HTTP::API::V2
  require 'puppet/network/http/api/v2/environments'
  require 'puppet/network/http/api/v2/authorization'

  def self.routes
    path(%r{^/v2\.0}).
      get(Authorization.new).
      chain(ENVIRONMENTS, NOT_FOUND)
  end

  private

  def self.path(path)
    Puppet::Network::HTTP::Route.path(path)
  end

  def self.provide(&block)
    lambda do |request, response|
      block.call.call(request, response)
    end
  end

  NOT_FOUND = Puppet::Network::HTTP::Route.
    path(/.*/).
    any(lambda do |req, res|
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new(req.path, Puppet::Network::HTTP::Issues::HANDLER_NOT_FOUND)
    end)

  ENVIRONMENTS = path(%r{^/environments$}).get(provide do
    Environments.new(Puppet.lookup(:environments))
  end)
end
