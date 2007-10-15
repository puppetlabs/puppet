require 'webrick'
require 'webrick/https'

class Puppet::Network::HTTP::WEBrick < WEBrick::HTTPServer
    def initialize(args = {})
        @listening = false
    end
    
    def listen(args = {})
        raise ArgumentError if args.keys.empty?
        raise "WEBrick server is already listening" if listening?
        # TODO / FIXME: this should be moved out of the wacky Puppet global namespace!
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
