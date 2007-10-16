require 'mongrel'

class Puppet::Network::HTTP::Mongrel
    def initialize(args = {})
        @listening = false
    end
    
    def listen(args = {})
        raise ArgumentError, ":handlers must be specified." if !args[:handlers] or args[:handlers].empty?
        raise ArgumentError, ":protocols must be specified." if !args[:protocols] or args[:protocols].empty?
        raise ArgumentError, ":address must be specified." unless args[:address]
        raise ArgumentError, ":port must be specified." unless args[:port]
        raise "Mongrel server is already listening" if listening?
        
        @protocols = args[:protocols]
        @handlers = args[:handlers]
        @server = Mongrel::HttpServer.new(args[:address], args[:port])

        setup_handlers

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
    
  private
  
    def setup_handlers
        @protocols.each do |protocol|
            @handlers.each do |handler|
                class_for_protocol(protocol).new(:server => @server, :handler => handler)
            end
        end
    end
  
    # TODO/FIXME: need a spec which forces delegation to the real class
    def class_for_protocol(protocol)
        Class.new do
            def initialize(args = {})
            end
        end
    end
end
