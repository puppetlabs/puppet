require 'puppet/network/http/handler'

class Puppet::Network::HTTP::MongrelREST < Puppet::Network::HTTP::Handler

  private
    
    def register_handler
        @server.register('/' + @handler.to_s, self)
        @server.register('/' + @handler.to_s + 's', self)
    end
    
    def http_method(request)
        request.params[Mongrel::Const::REQUEST_METHOD]
    end
    
    def path(request)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = '/' + request.params[Mongrel::Const::REQUEST_PATH].split('/')[1]
    end
    
    def request_key(request)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = request.params[Mongrel::Const::REQUEST_PATH].split('/')[2]        
    end
    
    def body(request)
        request.body
    end
    
    def params(request)
        Mongrel::HttpRequest.query_parse(request.params["QUERY_STRING"])
    end
    
    def encode_result(request, response, result, status = 200)
        response.start(status) do |head, body|
            body.write(result)
        end
    end
end
