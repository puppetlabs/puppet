class Puppet::Network::Client::Runner < Puppet::Network::Client::ProxyClient
    @drivername = :Runner

    # set up the appropriate interface methods
    @handler = Puppet::Network::Server::Runner
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:Runner)
            hash[:Runner] = Puppet::Network::Server::Runner.new()
        end

        super(hash)
    end
end

# $Id$
