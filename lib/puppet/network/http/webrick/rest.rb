require 'puppet/network/http/handler'
require 'resolv'

class Puppet::Network::HTTP::WEBrickREST < WEBrick::HTTPServlet::AbstractServlet

    include Puppet::Network::HTTP::Handler

    def initialize(server, handler)
        raise ArgumentError, "server is required" unless server
        super(server)
        initialize_for_puppet(:server => server, :handler => handler)
    end

    # Retrieve the request parameters, including authentication information.
    def params(request)
        result = request.query
        result = decode_params(result)
        result.merge(client_information(request))
    end

    # WEBrick uses a service() method to respond to requests.  Simply delegate to the handler response() method.
    def service(request, response)
        process(request, response)
    end

    def accept_header(request)
        request["accept"]
    end

    def content_type_header(request)
        request["content-type"]
    end

    def http_method(request)
        request.request_method
    end

    def path(request)
        request.path
    end

    def body(request)
        request.body
    end

    # Set the specified format as the content type of the response.
    def set_content_type(response, format)
        response["content-type"] = format_to_mime(format)
    end

    def set_response(response, result, status = 200)
        response.status = status
        response.body          = result if status >= 200 and status != 304
        response.reason_phrase = result if status < 200 or status >= 300
    end

    # Retrieve node/cert/ip information from the request object.
    def client_information(request)
        result = {}
        if peer = request.peeraddr and ip = peer[3]
            result[:ip] = ip
        end

        # If they have a certificate (which will almost always be true)
        # then we get the hostname from the cert, instead of via IP
        # info
        result[:authenticated] = false
        if cert = request.client_cert and nameary = cert.subject.to_a.find { |ary| ary[0] == "CN" }
            result[:node] = nameary[1]
            result[:authenticated] = true
        else
            result[:node] = resolve_node(result)
        end

        result
    end
end
