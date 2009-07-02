
require 'puppet/network/http'
require 'puppet/network/http/rack/rest'
require 'puppet/network/http/rack/xmlrpc'

# An rack application, for running the Puppet HTTP Server.
class Puppet::Network::HTTP::Rack

    def initialize(args)
        raise ArgumentError, ":protocols must be specified." if !args[:protocols] or args[:protocols].empty?
        protocols = args[:protocols]

        # Always prepare a REST handler
        @rest_http_handler = Puppet::Network::HTTP::RackREST.new()
        protocols.delete :rest

        # Prepare the XMLRPC handler, for backward compatibility (if requested)
        @xmlrpc_path = '/RPC2'
        if args[:protocols].include?(:xmlrpc)
            raise ArgumentError, "XMLRPC was requested, but no handlers were given" if !args.include?(:xmlrpc_handlers)

            @xmlrpc_http_handler = Puppet::Network::HTTP::RackXMLRPC.new(args[:xmlrpc_handlers])
            protocols.delete :xmlrpc
        end

        raise ArgumentError, "there were unknown :protocols specified." if !protocols.empty?
    end

    # The real rack application (which needs to respond to call).
    # The work we need to do, roughly is:
    # * Read request (from env) and prepare a response
    # * Route the request to the correct handler
    # * Return the response (in rack-format) to our caller.
    def call(env)
        request = Rack::Request.new(env)
        response = Rack::Response.new()
        Puppet.debug 'Handling request: %s %s' % [request.request_method, request.fullpath]

        # if we shall serve XMLRPC, have /RPC2 go to the xmlrpc handler
        if @xmlrpc_http_handler and @xmlrpc_path == request.path_info[0, @xmlrpc_path.size]
            handler = @xmlrpc_http_handler
        else
            # everything else is handled by the new REST handler
            handler = @rest_http_handler
        end

        begin
            handler.process(request, response)
        rescue => detail
            # Send a Status 500 Error on unhandled exceptions.
            response.status = 500
            response['Content-Type'] = 'text/plain'
            response.write 'Internal Server Error: "%s"' % detail.message
            # log what happened
            Puppet.err "Puppet Server (Rack): Internal Server Error: Unhandled Exception: \"%s\"" % detail.message
            Puppet.err "Backtrace:"
            detail.backtrace.each { |line| Puppet.err " > %s" % line }
        end
        response.finish()
    end
end

