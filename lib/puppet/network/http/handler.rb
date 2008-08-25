module Puppet::Network::HTTP
end

module Puppet::Network::HTTP::Handler
    attr_reader :model, :server, :handler

    # Retrieve the accept header from the http request.
    def accept_header(request)
        raise NotImplementedError
    end

    # Which format to use when serializing our response.  Just picks
    # the first value in the accept header, at this point.
    def format_to_use(request)
        unless header = accept_header(request)
            raise ArgumentError, "An Accept header must be provided to pick the right format"
        end

        format = nil
        header.split(/,\s*/).each do |name|
            next unless format = Puppet::Network::FormatHandler.format(name)
            next unless format.suitable?
            return name
        end

        raise "No specified acceptable formats (%s) are functional on this machine" % header
    end

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
        return do_exception(response, e)
    end

    # Are we interacting with a singular instance?
    def singular?(request)
        %r{/#{handler.to_s}$}.match(path(request))
    end

    # Are we interacting with multiple instances?
    def plural?(request)
        %r{/#{handler.to_s}s$}.match(path(request))
    end

    # Set the response up, with the body and status.
    def set_response(response, body, status = 200)
        raise NotImplementedError
    end

    # Set the specified format as the content type of the response.
    def set_content_type(response, format)
        raise NotImplementedError
    end

    def do_exception(response, exception, status=400)
        if exception.is_a?(Exception)
            puts exception.backtrace if Puppet[:trace]
            puts exception if Puppet[:trace]
        end
        set_content_type(response, "text/plain")
        set_response(response, exception.to_s, status)
    end

    # Execute our find.
    def do_find(request, response)
        key = request_key(request) || raise(ArgumentError, "Could not locate lookup key in request path [#{path(request)}]")
        args = params(request)
        unless result = model.find(key, args)
            return do_exception(response, "Could not find %s %s" % [model.name, key], 404)
        end

        # The encoding of the result must include the format to use,
        # and it needs to be used for both the rendering and as
        # the content type.
        format = format_to_use(request)
        set_content_type(response, format)

        set_response(response, result.render(format))
    end

    # Execute our search.
    def do_search(request, response)
        args = params(request)
        if key = request_key(request)
            result = model.search(key, args)
        else
            result = model.search(args)
        end
        if result.nil? or (result.is_a?(Array) and result.empty?)
            return do_exception(response, "Could not find instances in %s with '%s'" % [model.name, args.inspect], 404)
        end

        format = format_to_use(request)
        set_content_type(response, format)

        set_response(response, model.render_multiple(format, result))
    end

    # Execute our destroy.
    def do_destroy(request, response)
        key = request_key(request) || raise(ArgumentError, "Could not locate lookup key in request path [#{path(request)}]")
        args = params(request)
        result = model.destroy(key, args)

        set_content_type(response, "yaml")

        set_response(response, result.to_yaml)
    end

    # Execute our save.
    def do_save(request, response)
        data = body(request).to_s
        raise ArgumentError, "No data to save" if !data or data.empty?
        args = params(request)

        format = format_to_use(request)

        obj = model.convert_from(format_to_use(request), data)
        result = save_object(obj, args)

        set_content_type(response, "yaml")

        set_response(response, result.to_yaml)
    end

  private

    # LAK:NOTE This has to be here for testing; it's a stub-point so
    # we keep infinite recursion from happening.
    def save_object(object, args)
        object.save(args)
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

    # methods to be overridden by the including web server class

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
end
