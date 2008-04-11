require 'webrick'
require 'webrick/https'
require 'puppet/network/http/webrick/rest'
require 'thread'

class Puppet::Network::HTTP::WEBrick
    def initialize(args = {})
        @listening = false
        @mutex = Mutex.new
    end
    
    def self.class_for_protocol(protocol)
        return Puppet::Network::HTTP::WEBrickREST if protocol.to_sym == :rest
        raise "Unknown protocol [#{protocol}]."
    end
    
    def listen(args = {})
        raise ArgumentError, ":handlers must be specified." if !args[:handlers] or args[:handlers].empty?
        raise ArgumentError, ":protocols must be specified." if !args[:protocols] or args[:protocols].empty?
        raise ArgumentError, ":address must be specified." unless args[:address]
        raise ArgumentError, ":port must be specified." unless args[:port]
        
        @protocols = args[:protocols]
        @handlers = args[:handlers]        
        @server = WEBrick::HTTPServer.new(:BindAddress => args[:address], :Port => args[:port])
        setup_handlers

        @mutex.synchronize do
            raise "WEBrick server is already listening" if @listening        
            @listening = true
            @thread = Thread.new { @server.start }
        end
    end
    
    def unlisten
        @mutex.synchronize do
            raise "WEBrick server is not listening" unless @listening
            @server.shutdown
            @thread.join
            @server = nil
            @listening = false
        end
    end
    
    def listening?
        @mutex.synchronize do
            @listening
        end
    end

  private
    
    def setup_handlers
        @protocols.each do |protocol|
            klass = self.class.class_for_protocol(protocol)
            @handlers.each do |handler|
                @server.mount('/' + handler.to_s, klass, handler)
                @server.mount('/' + handler.to_s + 's', klass, handler)
            end
        end
    end
end
