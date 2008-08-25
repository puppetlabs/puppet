require 'puppet/network/http/handler'

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
        result.merge(client_information(request))
    end

    # WEBrick uses a service() method to respond to requests.  Simply delegate to the handler response() method.
    def service(request, response)
        process(request, response)
    end

    def accept_header(request)
        request["accept"]
    end

    def http_method(request)
        request.request_method
    end

    def path(request)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = '/' + request.path.split('/')[1]
    end

    def request_key(request)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = request.path.split('/', 3)[2]
    end

    def body(request)
        request.body
    end

    # Set the specified format as the content type of the response.
    def set_content_type(response, format)
        response["content-type"] = format
    end

    def set_response(response, result, status = 200)
        response.status = status
        if status >= 200 and status < 300
            response.body = result
        else
            response.reason_phrase = result
        end
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
        end

        result
    end
end
