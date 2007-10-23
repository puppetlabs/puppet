require 'puppet/network/http/handler'

class Puppet::Network::HTTP::WEBrickREST < Puppet::Network::HTTP::Handler

    # WEBrick uses a service() method to respond to requests.  Simply delegate to the handler response() method.
    def service(request, response)
        process(request, response)
    end

  private
    
    def register_handler
        @server.mount('/' + @handler.to_s, self)
        @server.mount('/' + @handler.to_s + 's', self)
    end

    def http_method(request)
        request.request_method
    end
    
    def path(request)
        '/' + request.path.split('/')[1]
    end
    
    def request_key(request)
        request.path.split('/')[2]
    end
    
    def body(request)
        request.body
    end
    
    def params(request)
        request.query
    end
    
    def encode_result(request, response, result)
        response.status = 200
    end
end