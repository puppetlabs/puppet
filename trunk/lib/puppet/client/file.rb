class Puppet::Client::FileClient < Puppet::Client::ProxyClient
    @drivername = :FileServer

    # set up the appropriate interface methods
    @handler = Puppet::Server::FileServer

    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:FileServer)
            unless hash[:FileServer].is_a?(Puppet::Server::FileServer)
                raise Puppet::DevError, "Must pass an actual FS object"
            end
        end

        super(hash)
    end
end

# $Id$
