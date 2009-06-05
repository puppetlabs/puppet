module Puppet::Network::HTTP
    def self.server_class_by_type(kind)
        case kind.to_sym
        when :webrick
            require 'puppet/network/http/webrick'
            return Puppet::Network::HTTP::WEBrick
        when :mongrel
            raise ArgumentError, "Mongrel is not installed on this platform" unless Puppet.features.mongrel?
            require 'puppet/network/http/mongrel'
            return Puppet::Network::HTTP::Mongrel
        else
            raise ArgumentError, "Unknown HTTP server name [#{kind}]"
        end
    end
end
