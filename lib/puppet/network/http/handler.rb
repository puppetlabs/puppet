class Puppet::Network::HTTP::Handler
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
    
  # methods specific to a given web server
    
    def register_handler
        raise UnimplementedError
    end
    
    def http_method(request)
        raise UnimplementedError
    end
    
    def path(request)
        raise UnimplementedError
    end    
end
