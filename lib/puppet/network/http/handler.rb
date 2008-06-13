module Puppet::Network::HTTP::Handler

    def initialize_for_puppet(args = {})
        raise ArgumentError unless @server = args[:server]
        raise ArgumentError unless @handler = args[:handler]
        @model = find_model_for_handler(@handler)
    end

    # handle an HTTP request
    def process(request, response)
        return do_find(request, response)       if get?(request)    and singular?(request)
        return do_search(request, response)     if get?(request)    and plural?(request)
        return do_destroy(request, response)    if delete?(request) and singular?(request)
        return do_save(request, response)       if put?(request)    and singular?(request)
        raise ArgumentError, "Did not understand HTTP #{http_method(request)} request for '#{path(request)}'"
    rescue Exception => e
        return do_exception(request, response, e)
    end

  private

    def model
        @model
    end

    def do_find(request, response)
        key = request_key(request) || raise(ArgumentError, "Could not locate lookup key in request path [#{path(request)}]")
        args = params(request)
        result = model.find(key, args).to_yaml
        encode_result(request, response, result)
    end

    def do_search(request, response)
        args = params(request)
        result = model.search(args).collect {|result| result.to_yaml }.to_yaml
        encode_result(request, response, result) 
    end

    def do_destroy(request, response)
        key = request_key(request) || raise(ArgumentError, "Could not locate lookup key in request path [#{path(request)}]")
        args = params(request)
        result = model.destroy(key, args)
        encode_result(request, response, YAML.dump(result))
    end

    def do_save(request, response)
        data = body(request).to_s
        raise ArgumentError, "No data to save" if !data or data.empty?
        args = params(request)
        obj = model.from_yaml(data)
        result = save_object(obj, args).to_yaml
        encode_result(request, response, result)
    end

    # LAK:NOTE This has to be here for testing; it's a stub-point so
    # we keep infinite recursion from happening.
    def save_object(object, args)
        object.save(args)
    end

    def do_exception(request, response, exception, status=404)
        encode_result(request, response, exception.to_yaml, status)
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

    # methods to be overridden by the including web server class

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

    def params(request)
        raise NotImplementedError
    end

    def encode_result(request, response, result, status = 200)
        raise NotImplementedError
    end
end
