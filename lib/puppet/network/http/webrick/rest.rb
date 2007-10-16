require 'puppet/network/http/handler'

class Puppet::Network::HTTP::WEBrickREST < Puppet::Network::HTTP::Handler

    # WEBrick uses a service() method to respond to requests.  Simply delegate to the handler response() method.
    def service(request, response)
        process(request, response)
    end

  private
    
    def register_handler
        @model = find_model_for_handler(@handler)
        @server.mount('/' + @handler.to_s, self)
        @server.mount('/' + @handler.to_s + 's', self)
    end

    def http_method(request)
        request.request_method
    end
    
    def path(request)
        request.path
    end
end