require 'openssl'
require 'puppet/ssl/certificate'

class Puppet::Network::HTTP::RackHttpHandler

    def initialize()
    end

    # do something useful with request (a Rack::Request) and use
    # response to fill your Rack::Response
    def process(request, response)
        raise NotImplementedError, "Your RackHttpHandler subclass is supposed to override service(request)"
    end

end

