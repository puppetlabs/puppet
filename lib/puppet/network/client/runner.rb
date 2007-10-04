class Puppet::Network::Client::Runner < Puppet::Network::Client::ProxyClient
    self.mkmethods

    def initialize(hash = {})
        if hash.include?(:Runner)
            hash[:Runner] = self.class.handler.new()
        end

        super(hash)
    end
end

