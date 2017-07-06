require 'rack'
require 'rack/request'
require 'rack/response'

require 'puppet/network/http'
require 'puppet/network/http/rack/rest'

# An rack application, for running the Puppet HTTP Server.
class Puppet::Network::HTTP::Rack
  # The real rack application (which needs to respond to call).
  # The work we need to do, roughly is:
  # * Read request (from env) and prepare a response
  # * Route the request to the correct handler
  # * Return the response (in rack-format) to our caller.
  def call(env)
    request = Rack::Request.new(env)
    response = Rack::Response.new
    Puppet.debug 'Handling request: %s %s' % [request.request_method, request.fullpath]

    begin
      Puppet::Network::HTTP::RackREST.new.process(request, response)
    rescue => detail
      # Send a Status 500 Error on unhandled exceptions.
      response.status = 500
      response['Content-Type'] = 'text/plain'
      response.write 'Internal Server Error: "%s"' % detail.message
      # log what happened
      Puppet.log_exception(detail, "Puppet Server (Rack): Internal Server Error: Unhandled Exception: \"%s\"" % detail.message)
    end
    response.finish
  end
end

