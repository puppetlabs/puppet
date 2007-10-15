require 'mongrel'

class Puppet::Network::HTTP::Mongrel
    def initialize(args = {})
        @listening = false
    end
    
    def listen(args = {})
        raise ArgumentError, ":handlers must be specified." if !args[:handlers] or args[:handlers].keys.empty?
        raise ArgumentError, ":address must be specified." unless args[:address]
        raise ArgumentError, ":port must be specified." unless args[:port]
        raise "Mongrel server is already listening" if listening?
        @server = Mongrel::HttpServer.new(args[:address], args[:port])
        @server.run
        @listening = true
    end
    
    def unlisten
        raise "Mongrel server is not listening" unless listening?
        @server.graceful_shutdown
        @listening = false
    end
    
    def listening?
        @listening
    end
end
