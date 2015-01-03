module Puppet::Network::HTTP::API::Master::V2
  require 'puppet/network/http/api/master/v2/environments'
  require 'puppet/network/http/api/master/v2/authorization'

  def self.routes
    path(%r{^/v2\.0}).
      get(Authorization.new).
      chain(ENVIRONMENTS, Puppet::Network::HTTP::API.not_found)
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

  ENVIRONMENTS = path(%r{^/environments$}).get(provide do
    Environments.new(Puppet.lookup(:environments))
  end)
end
