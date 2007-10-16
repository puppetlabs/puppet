class Puppet::Network::HTTP::MongrelREST
    def initialize(args = {})
        raise ArgumentError unless @server = args[:server]
        raise ArgumentError unless @handler = args[:handler]
        register_handler
    end
    
    # handle an HTTP request coming from Mongrel
    def process(request, response)
        return @model.find     if get?(request)    and singular?(request)
        return @model.search   if get?(request)    and plural?(request)
        return @model.destroy  if delete?(request) and singular?(request)
        return @model.new.save if put?(request) and singular?(request)
        raise ArgumentError, "Did not understand HTTP #{http_method(request)} request for '#{path(request)}'"
        # TODO: here, raise an exception, or do some defaulting or something
    end
    
  private
    
    def find_model_for_handler(handler)
        Puppet::Indirector::Indirection.model(handler) || 
            raise(ArgumentError, "Cannot locate indirection [#{handler}].")
    end
    
    def get?(request)
        http_method(request) == 'GET'
    end
    
    def put?(request)
        http_method(request) == 'PUT'
    end
    
    def delete?(request)
        http_method(request) == 'DELETE'
    end
    
    def singular?(request)
        %r{/#{@handler.to_s}$}.match(path(request))
    end
    
    def plural?(request)
        %r{/#{@handler.to_s}s$}.match(path(request))
    end
    
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
