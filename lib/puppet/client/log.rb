class Puppet::Client::LogClient < Puppet::Client::ProxyClient
    @drivername = :Logger

    # set up the appropriate interface methods
    @handler = Puppet::Server::Logger
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:Logger)
            hash[:Logger] = Puppet::Server::Logger.new()
        end

        super(hash)
    end
end

# $Id$
