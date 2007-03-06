class Puppet::Network::Client::Logger < Puppet::Network::Client::ProxyClient
    @handler = Puppet::Network::Handler.handler(:logger)
    self.mkmethods
end

# $Id$
