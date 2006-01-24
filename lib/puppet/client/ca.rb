class Puppet::Client::CAClient < Puppet::Client::ProxyClient
    @drivername = :CA

    # set up the appropriate interface methods
    @handler = Puppet::Server::CA
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:CA)
            hash[:CA] = Puppet::Server::CA.new()
        end

        super(hash)
    end
end

# $Id$
