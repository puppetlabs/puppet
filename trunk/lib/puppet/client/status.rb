class Puppet::Client::StatusClient < Puppet::Client::ProxyClient
    # set up the appropriate interface methods
    @handler = Puppet::Server::ServerStatus
    self.mkmethods
end

# $Id$
