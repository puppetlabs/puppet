class Puppet::Client::CA < Puppet::Client::ProxyClient
    @drivername = :CA

    # set up the appropriate interface methods
    @handler = Puppet::Server::CA
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:CA)
            if hash[:CA].is_a? Hash
                hash[:CA] = Puppet::Server::CA.new(hash[:CA])
            else
                hash[:CA] = Puppet::Server::CA.new()
            end
        end

        super(hash)
    end
end

# $Id$
