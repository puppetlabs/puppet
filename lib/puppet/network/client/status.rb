class Puppet::Network::Client::StatusClient < Puppet::Network::Client::ProxyClient
    # set up the appropriate interface methods
    @handler = Puppet::Network::Server::ServerStatus
    self.mkmethods
end

# $Id$
