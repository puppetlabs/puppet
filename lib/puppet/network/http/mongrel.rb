require 'mongrel'

class Puppet::Network::HTTP::Mongrel
    def initialize(args = {})
        @listening = false
    end
    
    def listen(args = {})
        raise ArgumentError if args.keys.empty?
        raise "Mongrel server is already listening" if @listening
        @server = Mongrel::HttpServer.new("0.0.0.0", "3000")
        @server.run
        @listening = true
    end
    
    def unlisten
        raise "Mongrel server is not listening" unless @listening
        @server.graceful_shutdown
        @listening = false
    end
end
