class Puppet::Network::HTTP::Handler
    def initialize(args = {})
        raise ArgumentError unless @server = args[:server]
        raise ArgumentError unless @handler = args[:handler]
        @model = find_model_for_handler(@handler)
        register_handler
    end
    
    # handle an HTTP request coming from Mongrel
    def process(request, response)
        return do_find(request, response)       if get?(request)    and singular?(request)
        return do_search(request, response)     if get?(request)    and plural?(request)
        return do_destroy(request, response)    if delete?(request) and singular?(request)
        return do_save(request, response)       if put?(request) and singular?(request)
        raise ArgumentError, "Did not understand HTTP #{http_method(request)} request for '#{path(request)}'"
    end
    
  private
    
    def do_find(request, response)
        key = request_key(request) || raise(ArgumentError, "Could not locate lookup key in request path [#{path}]")
        @model.find(key)
    end

    def do_search(request, response)
        @model.search
    end

    def do_destroy(request, response)
        key = request_key(request) || raise(ArgumentError, "Could not locate lookup key in request path [#{path}]")
        @model.destroy(key)
    end

    def do_save(request, response)
        data = body(request)
        raise ArgumentError, "No data to save" if !data or data.empty?
        @model.new.save(:data => data)
    end
  
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
        raise NotImplementedError
    end
    
    def http_method(request)
        raise NotImplementedError
    end
    
    def path(request)
        raise NotImplementedError
    end    
    
    def request_key(request)
        raise NotImplementedError
    end
    
    def body(request)
        raise NotImplementedError
    end
end
