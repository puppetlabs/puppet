class Puppet::Network::HTTP
    def self.server_class_by_type(kind)
        return Puppet::Network::HTTP::WEBRick if kind == :webrick
        return Puppet::Network::HTTP::Mongrel if kind == :mongrel
        raise ArgumentError, "Unknown HTTP server name [#{kind}]"
    end
end

require 'puppet/network/http/webrick'
require 'puppet/network/http/mongrel'
