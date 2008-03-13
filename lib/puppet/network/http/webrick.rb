require 'webrick'
require 'webrick/https'
require 'puppet/network/http/webrick/rest'
require 'thread'

class Puppet::Network::HTTP::WEBrick
    def initialize(args = {})
        @listening = false
        @mutex = Mutex.new
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
