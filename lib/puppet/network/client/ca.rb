require 'puppet/network/client/proxy'

class Puppet::Network::Client::CA < Puppet::Network::Client::ProxyClient
    @drivername = :CA

    # set up the appropriate interface methods
    @handler = Puppet::Network::Server::CA
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:CA)
            if hash[:CA].is_a? Hash
                hash[:CA] = Puppet::Network::Server::CA.new(hash[:CA])
            else
                hash[:CA] = Puppet::Network::Server::CA.new()
            end
        end

        super(hash)
    end
end

# $Id$
