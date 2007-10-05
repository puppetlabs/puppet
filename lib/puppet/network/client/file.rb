class Puppet::Network::Client::File < Puppet::Network::Client::ProxyClient
    @handler = Puppet::Network::Handler.handler(:fileserver)
    @drivername = :FileServer
    self.mkmethods
end

