require 'puppet/network/http/handler'
require 'puppet/network/http/rack/httphandler'

class Puppet::Network::HTTP::RackREST < Puppet::Network::HTTP::RackHttpHandler

    include Puppet::Network::HTTP::Handler

    HEADER_ACCEPT = 'HTTP_ACCEPT'.freeze
    ContentType = 'Content-Type'.freeze

    def initialize(args={})
        super()
        initialize_for_puppet(args)
    end

    def set_content_type(response, format)
        response[ContentType] = format_to_mime(format)
    end

    # produce the body of the response
    def set_response(response, result, status = 200)
        response.status = status
        response.write result
    end

    # Retrieve the accept header from the http request.
    def accept_header(request)
        request.env[HEADER_ACCEPT]
    end

    # Retrieve the accept header from the http request.
    def content_type_header(request)
        request.content_type
    end

    # Return which HTTP verb was used in this request.
    def http_method(request)
        request.request_method
    end

    # Return the query params for this request.
    def params(request)
        result = decode_params(request.params)
        result.merge(extract_client_info(request))
    end

    # what path was requested? (this is, without any query parameters)
    def path(request)
        request.path
    end

    # return the request body
    # request.body has some limitiations, so we need to concat it back
    # into a regular string, which is something puppet can use.
    def body(request)
        body = ''
        request.body.each { |part| body += part }
        body
    end

    def extract_client_info(request)
        result = {}
        result[:ip] = request.ip

        # if we find SSL info in the headers, use them to get a hostname.
        # try this with :ssl_client_header, which defaults should work for
        # Apache with StdEnvVars.
        if dn = request.env[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
            result[:node] = dn_matchdata[1].to_str
            result[:authenticated] = (request.env[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
        else
            result[:node] = resolve_node(result)
            result[:authenticated] = false
        end

        result
    end

end
