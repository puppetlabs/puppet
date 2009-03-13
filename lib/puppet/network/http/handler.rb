module Puppet::Network::HTTP
end

module Puppet::Network::HTTP::Handler

    # How we map http methods and the indirection name in the URI
    # to an indirection method.
    METHOD_MAP = {
        "GET" => {
            :plural => :search,
            :singular => :find
        },
        "PUT" => {
            :singular => :save
        },
        "DELETE" => {
            :singular => :destroy
        }
    }

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
        indirection_request = uri2indirection(path(request), params(request), http_method(request))

        send("do_%s" % indirection_request.method, indirection_request, request, response)
    rescue Exception => e
        return do_exception(response, e)
    end

    def uri2indirection(http_method, uri, params)
        environment, indirection, key = uri.split("/", 4)[1..-1] # the first field is always nil because of the leading slash

        raise ArgumentError, "The environment must be purely alphanumeric, not '%s'" % environment unless environment =~ /^\w+$/
        raise ArgumentError, "The indirection name must be purely alphanumeric, not '%s'" % indirection unless indirection =~ /^\w+$/

        method = indirection_method(http_method, indirection)

        params[:environment] = environment

        raise ArgumentError, "No request key specified in %s" % uri if key == "" or key.nil?

        key = URI.unescape(key)

        Puppet::Indirector::Request.new(indirection, method, key, params)
    end

    def indirection2uri(request)
        indirection = request.method == :search ? request.indirection_name.to_s + "s" : request.indirection_name.to_s
        "/#{request.environment.to_s}/#{indirection}/#{request.escaped_key}#{request.query_string}"
    end

    def indirection_method(http_method, indirection)
        unless METHOD_MAP[http_method]
            raise ArgumentError, "No support for http method %s" % http_method
        end

        unless method = METHOD_MAP[http_method][plurality(indirection)]
            raise ArgumentError, "No support for plural %s operations" % http_method
        end

        return method
    end

    def plurality(indirection)
        result = (indirection == handler.to_s + "s") ? :plural : :singular

        indirection.sub!(/s$/, '') if result

        result
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
            Puppet.err(exception)
        end
        set_content_type(response, "text/plain")
        set_response(response, exception.to_s, status)
    end

    # Execute our find.
    def do_find(indirection_request, request, response)
        unless result = model.find(indirection_request.key, indirection_request.options)
            return do_exception(response, "Could not find %s %s" % [model.name, indirection_request.key], 404)
        end

        # The encoding of the result must include the format to use,
        # and it needs to be used for both the rendering and as
        # the content type.
        format = format_to_use(request)
        set_content_type(response, format)

        set_response(response, result.render(format))
    end

    # Execute our search.
    def do_search(indirection_request, request, response)
        result = model.search(indirection_request.key, indirection_request.options)

        if result.nil? or (result.is_a?(Array) and result.empty?)
            return do_exception(response, "Could not find instances in %s with '%s'" % [model.name, indirection_request.options.inspect], 404)
        end

        format = format_to_use(request)
        set_content_type(response, format)

        set_response(response, model.render_multiple(format, result))
    end

    # Execute our destroy.
    def do_destroy(indirection_request, request, response)
        result = model.destroy(indirection_request.key, indirection_request.options)

        set_content_type(response, "yaml")

        set_response(response, result.to_yaml)
    end

    # Execute our save.
    def do_save(indirection_request, request, response)
        data = body(request).to_s
        raise ArgumentError, "No data to save" if !data or data.empty?

        format = format_to_use(request)

        obj = model.convert_from(format_to_use(request), data)
        result = save_object(indirection_request, obj)

        set_content_type(response, "yaml")

        set_response(response, result.to_yaml)
    end

  private

    # LAK:NOTE This has to be here for testing; it's a stub-point so
    # we keep infinite recursion from happening.
    def save_object(ind_request, object)
        object.save(ind_request.options)
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

    def decode_params(params)
        params.inject({}) do |result, ary|
            param, value = ary
            value = URI.unescape(value)
            if value =~ /^---/
                value = YAML.load(value)
            else
                value = true if value == "true"
                value = false if value == "false"
                value = Integer(value) if value =~ /^\d+$/
                value = value.to_f if value =~ /^\d+\.\d+$/
            end
            result[param.to_sym] = value
            result
        end
    end
end
