module Puppet::Network::HTTP
end

require 'puppet/network/http/api/v1'
require 'puppet/network/rest_authorization'
require 'puppet/network/rights'
require 'resolv'

module Puppet::Network::HTTP::Handler
    include Puppet::Network::HTTP::API::V1
    include Puppet::Network::RestAuthorization

    attr_reader :server, :handler

    # Retrieve the accept header from the http request.
    def accept_header(request)
        raise NotImplementedError
    end

    # Retrieve the Content-Type header from the http request.
    def content_type_header(request)
        raise NotImplementedError
    end

    # Which format to use when serializing our response or interpreting the request.  
    # IF the client provided a Content-Type use this, otherwise use the Accept header
    # and just pick the first value.
    def format_to_use(request)
        unless header = accept_header(request)
            raise ArgumentError, "An Accept header must be provided to pick the right format"
        end

        format = nil
        header.split(/,\s*/).each do |name|
            next unless format = Puppet::Network::FormatHandler.format(name)
            next unless format.suitable?
            return format
        end

        raise "No specified acceptable formats (%s) are functional on this machine" % header
    end

    def request_format(request)
        if header = content_type_header(request)
            header.gsub!(/\s*;.*$/,'') # strip any charset
            format = Puppet::Network::FormatHandler.mime(header)
            raise "Client sent a mime-type (%s) that doesn't correspond to a format we support" % header if format.nil?
            return format.name.to_s if format.suitable?
        end

        raise "No Content-Type header was received, it isn't possible to unserialize the request"
    end

    def format_to_mime(format)
        format.is_a?(Puppet::Network::Format) ? format.mime : format
    end

    def initialize_for_puppet(server)
        @server = server
    end

    # handle an HTTP request
    def process(request, response)
        indirection_request = uri2indirection(http_method(request), path(request), params(request))

        check_authorization(indirection_request)

        send("do_%s" % indirection_request.method, indirection_request, request, response)
    rescue SystemExit,NoMemoryError
        raise
    rescue Exception => e
        return do_exception(response, e)
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
        if exception.is_a?(Puppet::Network::AuthorizationError)
            # make sure we return the correct status code
            # for authorization issues
            status = 403 if status == 400
        end
        if exception.is_a?(Exception)
            puts exception.backtrace if Puppet[:trace]
            Puppet.err(exception)
        end
        set_content_type(response, "text/plain")
        set_response(response, exception.to_s, status)
    end

    # Execute our find.
    def do_find(indirection_request, request, response)
        unless result = indirection_request.model.find(indirection_request.key, indirection_request.to_hash)
            Puppet.info("Could not find %s for '%s'" % [indirection_request.indirection_name, indirection_request.key])
            return do_exception(response, "Could not find %s %s" % [indirection_request.indirection_name, indirection_request.key], 404)
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
        result = indirection_request.model.search(indirection_request.key, indirection_request.to_hash)

        if result.nil? or (result.is_a?(Array) and result.empty?)
            return do_exception(response, "Could not find instances in %s with '%s'" % [indirection_request.indirection_name, indirection_request.to_hash.inspect], 404)
        end

        format = format_to_use(request)
        set_content_type(response, format)

        set_response(response, indirection_request.model.render_multiple(format, result))
    end

    # Execute our destroy.
    def do_destroy(indirection_request, request, response)
        result = indirection_request.model.destroy(indirection_request.key, indirection_request.to_hash)

        return_yaml_response(response, result)
    end

    # Execute our save.
    def do_save(indirection_request, request, response)
        data = body(request).to_s
        raise ArgumentError, "No data to save" if !data or data.empty?

        format = request_format(request)
        obj = indirection_request.model.convert_from(format, data)
        result = save_object(indirection_request, obj)
        return_yaml_response(response, result)
    end

    # resolve node name from peer's ip address
    # this is used when the request is unauthenticated
    def resolve_node(result)
        begin
            return Resolv.getname(result[:ip])
        rescue => detail
            Puppet.err "Could not resolve %s: %s" % [result[:ip], detail]
        end
        return result[:ip]
    end

  private

    def return_yaml_response(response, body)
        set_content_type(response, Puppet::Network::FormatHandler.format("yaml"))
        set_response(response, body.to_yaml)
    end

    # LAK:NOTE This has to be here for testing; it's a stub-point so
    # we keep infinite recursion from happening.
    def save_object(ind_request, object)
        object.save(ind_request.to_hash)
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
            next result if param.nil? || param.empty?

            param = param.to_sym

            # These shouldn't be allowed to be set by clients
            # in the query string, for security reasons.
            next result if param == :node
            next result if param == :ip
            value = CGI.unescape(value)
            if value =~ /^---/
                value = YAML.load(value)
            else
                value = true if value == "true"
                value = false if value == "false"
                value = Integer(value) if value =~ /^\d+$/
                value = value.to_f if value =~ /^\d+\.\d+$/
            end
            result[param] = value
            result
        end
    end
end
