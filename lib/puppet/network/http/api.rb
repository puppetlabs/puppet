class Puppet::Network::HTTP::API
  require 'puppet/version'

  def self.not_found
    Puppet::Network::HTTP::Route.
      path(/.*/).
      any(lambda do |req, res|
        raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("No route for #{req.method} #{req.path}", Puppet::Network::HTTP::Issues::HANDLER_NOT_FOUND)
      end)
  end

  def self.not_found_upgrade
    Puppet::Network::HTTP::Route.
      path(/.*/).
      any(lambda do |req, res|
        raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("Error: Invalid URL - Puppet expects requests that conform to the " +
                                                                      "/puppet and /puppet-ca APIs.\n\n" +
                                                                      "Note that Puppet 3 agents aren't compatible with this version; if you're " +
                                                                      "running Puppet 3, you must either upgrade your agents to match the server " +
                                                                      "or point them to a server running Puppet 3.\n\n" +
                                                                      "Master Info:\n" +
                                                                      "  Puppet version: #{Puppet.version}\n" +
                                                                      "  Supported /puppet API versions: #{Puppet::Network::HTTP::MASTER_URL_VERSIONS}\n" +
                                                                      "  Supported /puppet-ca API versions: #{Puppet::Network::HTTP::CA_URL_VERSIONS}",
                                                                  Puppet::Network::HTTP::Issues::HANDLER_NOT_FOUND)
      end)
  end

  def self.master_routes
    master_prefix = Regexp.new("^#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/")
    Puppet::Network::HTTP::Route.path(master_prefix).
      any.
      chain(Puppet::Network::HTTP::API::Master::V3.routes,
            Puppet::Network::HTTP::API.not_found)
  end

  def self.ca_routes
    ca_prefix = Regexp.new("^#{Puppet::Network::HTTP::CA_URL_PREFIX}/")
    Puppet::Network::HTTP::Route.path(ca_prefix).
      any.
      chain(Puppet::Network::HTTP::API::CA::V1.routes,
            Puppet::Network::HTTP::API.not_found)
  end
end
