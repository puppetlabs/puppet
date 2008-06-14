require 'puppet/network/http/handler'

class Puppet::Network::HTTP::MongrelREST < Mongrel::HttpHandler

    include Puppet::Network::HTTP::Handler

    def initialize(args={})
        super()
        initialize_for_puppet(args)
    end

    # Return the query params for this request.  We had to expose this method for
    # testing purposes.
    def params(request)
        Mongrel::HttpRequest.query_parse(request.params["QUERY_STRING"]).merge(client_info(request))
    end

  private

    # which HTTP verb was used in this request
    def http_method(request)
        request.params[Mongrel::Const::REQUEST_METHOD]
    end

    # what path was requested?
    def path(request)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = '/' + request.params[Mongrel::Const::REQUEST_PATH].split('/')[1]
    end

    # return the key included in the request path
    def request_key(request)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = request.params[Mongrel::Const::REQUEST_PATH].split('/')[2]        
    end

    # return the request body
    def body(request)
        request.body
    end

    # produce the body of the response
    def encode_result(request, response, result, status = 200)
        response.start(status) do |head, body|
            body.write(result)
        end
    end

    def client_info(request)
        result = {}
        params = request.params
        result[:ip] = params["REMOTE_ADDR"]

        # JJM #906 The following dn.match regular expression is forgiving
        # enough to match the two Distinguished Name string contents
        # coming from Apache, Pound or other reverse SSL proxies.
        if dn = params[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
            result[:node] = dn_matchdata[1].to_str
            result[:authenticated] = (params[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
        else
            result[:authenticated] = false
        end

        return result
    end
end
