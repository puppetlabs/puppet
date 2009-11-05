require 'puppet/network/http/rack/httphandler'
require 'puppet/network/xmlrpc/server'
require 'resolv'

class Puppet::Network::HTTP::RackXMLRPC < Puppet::Network::HTTP::RackHttpHandler
    def initialize(handlers)
        @xmlrpc_server = Puppet::Network::XMLRPCServer.new
        handlers.each do |name|
            Puppet.debug "  -> register xmlrpc namespace %s" % name
            unless handler = Puppet::Network::Handler.handler(name)
                raise ArgumentError, "Invalid XMLRPC handler %s" % name
            end
            @xmlrpc_server.add_handler(handler.interface, handler.new({}))
        end
        super()
    end

    def process(request, response)
        # errors are sent as text/plain
        response['Content-Type'] = 'text/plain'
        if not request.post? then
            response.status = 405
            response.write 'Method Not Allowed'
            return
        end
        if request.media_type() != "text/xml" then
            response.status = 400
            response.write 'Bad Request'
            return
        end

        # get auth/certificate data
        client_request = build_client_request(request)

        response_body = @xmlrpc_server.process(request.body.read(), client_request)

        response.status = 200
        response['Content-Type'] =  'text/xml; charset=utf-8'
        response.write response_body
    end

    def build_client_request(request)
        ip = request.ip

        # if we find SSL info in the headers, use them to get a hostname.
        # try this with :ssl_client_header, which defaults should work for
        # Apache with StdEnvVars.
        if dn = request.env[Puppet[:ssl_client_header]] and dn_matchdata = dn.match(/^.*?CN\s*=\s*(.*)/)
            node = dn_matchdata[1].to_str
            authenticated = (request.env[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
        else
            begin
                node = Resolv.getname(ip)
            rescue => detail
                Puppet.err "Could not resolve %s: %s" % [ip, detail]
                node = "unknown"
            end
            authenticated = false
        end

        Puppet::Network::ClientRequest.new(node, ip, authenticated)
    end

end

