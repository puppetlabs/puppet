class Puppet::Client::Runner < Puppet::Client::ProxyClient
    @drivername = :Runner

    # set up the appropriate interface methods
    @handler = Puppet::Server::Runner
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:Runner)
            hash[:Runner] = Puppet::Server::Runner.new()
        end

        super(hash)
    end
end

# $Id$
