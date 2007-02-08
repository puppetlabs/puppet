class Puppet::Network::Client::LogClient < Puppet::Network::Client::ProxyClient
    @drivername = :Logger

    # set up the appropriate interface methods
    @handler = Puppet::Network::Server::Logger
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:Logger)
            hash[:Logger] = Puppet::Network::Server::Logger.new()
        end

        super(hash)
    end
end

# $Id$
