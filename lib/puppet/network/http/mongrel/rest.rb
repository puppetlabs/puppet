require 'puppet/network/http/handler'

class Puppet::Network::HTTP::MongrelREST < Mongrel::HttpHandler

    include Puppet::Network::HTTP::Handler

    ACCEPT_HEADER = "HTTP_ACCEPT".freeze # yay, zed's a crazy-man

    def initialize(args={})
        super()
        initialize_for_puppet(args)
    end

    def accept_header(request)
        request.params[ACCEPT_HEADER]
    end

    def content_type_header(request)
        request.params["HTTP_CONTENT_TYPE"]
    end

    # which HTTP verb was used in this request
    def http_method(request)
        request.params[Mongrel::Const::REQUEST_METHOD]
    end

    # Return the query params for this request.  We had to expose this method for
    # testing purposes.
    def params(request)
        params = Mongrel::HttpRequest.query_parse(request.params["QUERY_STRING"])
        params = decode_params(params)
        params.merge(client_info(request))
    end

    # what path was requested?
    def path(request)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
        #x = '/' + request.params[Mongrel::Const::REQUEST_PATH]
        request.params[Mongrel::Const::REQUEST_PATH]
    end

    # return the request body
    def body(request)
        request.body.read
    end

    def set_content_type(response, format)
        response.header['Content-Type'] = format_to_mime(format)
    end

    # produce the body of the response
    def set_response(response, result, status = 200)
        # Set the 'reason' (or 'message', as it's called in Webrick), when
        # we have a failure, unless we're on a version of mongrel that doesn't
        # support this.
        if status < 300
            response.start(status) { |head, body| body.write(result) }
        else
            begin
                response.start(status,false,result) { |head, body| body.write(result) }
            rescue ArgumentError
	        response.start(status)              { |head, body| body.write(result) }
            end
        end
    end

    def client_info(request)
        result = {}
        params = request.params
        result[:ip] = params["HTTP_X_FORWARDED_FOR"] ? params["HTTP_X_FORWARDED_FOR"].split(',').last.strip : params["REMOTE_ADDR"]

        # JJM #906 The following dn.match regular expression is forgiving
        # enough to match the two Distinguished Name string contents
        # coming from Apache, Pound or other reverse SSL proxies.
        if dn = params[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
            result[:node] = dn_matchdata[1].to_str
            result[:authenticated] = (params[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
        else
            result[:node] = resolve_node(result)
            result[:authenticated] = false
        end

        return result
    end
end
