require 'puppet/network/http/handler'

class Puppet::Network::HTTP::MongrelREST < Puppet::Network::HTTP::Handler

  private
    
    def register_handler
        @model = find_model_for_handler(@handler)
        @server.register('/' + @handler.to_s, self)
        @server.register('/' + @handler.to_s + 's', self)
    end
    
    def http_method(request)
        request.params[Mongrel::Const::REQUEST_METHOD]
    end
    
    def path(request)
        request.params[Mongrel::Const::REQUEST_PATH]
    end
end
