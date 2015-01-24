require 'puppet/network/http/handler'

class PuppetSpec::Handler
  include Puppet::Network::HTTP::Handler

  def initialize(* routes)
    register(routes)
  end

  def set_content_type(response, format)
    response[:content_type_header] = format
  end

  def set_response(response, body, status = 200)
    response[:body] = body
    response[:status] = status
  end

  def http_method(request)
    request[:method]
  end

  def path(request)
    request[:path]
  end

  def params(request)
    request[:params]
  end

  def client_cert(request)
    request[:client_cert]
  end

  def body(request)
    request[:body]
  end

  def headers(request)
    request[:headers] || {}
  end
end

class PuppetSpec::HandlerProfiler
  def start(metric, description)
  end

  def finish(context, metric, description)
  end

  def shutdown()
  end
end
