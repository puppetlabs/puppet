require 'webrick'
require 'webrick/https'

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
        
        # TODO / FIXME is this really necessary? -- or can we do it in both mongrel and webrick?
        Puppet.newservice(@server)
        Puppet.start
        
        @listening = true
    end
    
    def unlisten
        raise "WEBrick server is not listening" unless listening?
        shutdown
        @listening = false
    end
    
    def listening?
        @listening
    end
    
  private
    
    def setup_handlers
        @handlers.each do |handler|
            @protocols.each do |protocol|
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
