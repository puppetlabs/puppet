require 'webrick'
require 'webrick/https'

class Puppet::Network::HTTP::WEBrick
    def initialize(args = {})
        @listening = false
    end
    
    def listen(args = {})
        raise ArgumentError, ":handlers must be specified." if !args[:handlers] or args[:handlers].keys.empty?
        raise ArgumentError, ":address must be specified." unless args[:address]
        raise ArgumentError, ":port must be specified." unless args[:port]
        raise "WEBrick server is already listening" if listening?
        
        @server = WEBrick::HTTPServer.new(:BindAddress => args[:address], :Port => args[:port])
        
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
end
