require 'webrick'
require 'webrick/https'
require 'puppet/network/http/webrick/rest'

class Puppet::Network::HTTP::WEBrick
    def initialize(args = {})
        @listening = false
    end
    
    def listen(args = {})
        raise ArgumentError, ":handlers must be specified." if !args[:handlers] or args[:handlers].empty?
        raise ArgumentError, ":protocols must be specified." if !args[:protocols] or args[:protocols].empty?
        raise ArgumentError, ":address must be specified." unless args[:address]
        raise ArgumentError, ":port must be specified." unless args[:port]
        raise "WEBrick server is already listening" if listening?
        
        @protocols = args[:protocols]
        @handlers = args[:handlers]        
        @server = WEBrick::HTTPServer.new(:BindAddress => args[:address], :Port => args[:port])
        setup_handlers
        @server.start
        @listening = true
    end
    
    def unlisten
        raise "WEBrick server is not listening" unless listening?
        @server.shutdown
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
    
    def class_for_protocol(protocol)
        return Puppet::Network::HTTP::WEBrickREST if protocol.to_sym == :rest
        raise ArgumentError, "Unknown protocol [#{protocol}]."
    end
end
