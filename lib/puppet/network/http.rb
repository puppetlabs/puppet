class Puppet::Network::HTTP
    def self.server_class_by_type(kind)
        return Puppet::Network::HTTP::WEBrick if kind.to_sym == :webrick
        return Puppet::Network::HTTP::Mongrel if kind.to_sym == :mongrel
        raise ArgumentError, "Unknown HTTP server name [#{kind}]"
    end
end

require 'puppet/network/http/webrick'
require 'puppet/network/http/mongrel'
