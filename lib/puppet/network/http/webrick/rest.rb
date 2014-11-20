require 'puppet/network/http/handler'
require 'resolv'
require 'webrick'
require 'puppet/util/ssl'

class Puppet::Network::HTTP::WEBrickREST < WEBrick::HTTPServlet::AbstractServlet

  include Puppet::Network::HTTP::Handler

  def self.mutex
    @mutex ||= Mutex.new
  end

  def initialize(server)
    raise ArgumentError, "server is required" unless server
    register([Puppet::Network::HTTP::API::V2.routes, Puppet::Network::HTTP::API::V1.routes])
    super(server)
  end

  # Retrieve the request parameters, including authentication information.
  def params(request)
    params = request.query || {}

    params = Hash[params.collect do |key, value|
      all_values = value.list
      [key, all_values.length == 1 ? value : all_values]
    end]

    params = decode_params(params)
    params.merge(client_information(request))
  end

  # WEBrick uses a service method to respond to requests.  Simply delegate to
  # the handler response method.
  def service(request, response)
    self.class.mutex.synchronize do
      process(request, response)
    end
  end

  def headers(request)
    result = {}
    request.each do |k, v|
      result[k.downcase] = v
    end
    result
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

  def client_cert(request)
    if cert = request.client_cert
      cert = Puppet::SSL::Certificate.from_instance(cert)
      warn_if_near_expiration(cert)
      cert
    else
      nil
    end
  end

  # Set the specified format as the content type of the response.
  def set_content_type(response, format)
    response["content-type"] = format_to_mime(format)
  end

  def set_response(response, result, status = 200)
    response.status = status
    if status >= 200 and status != 304
      response.body = result
      response["content-length"] = result.stat.size if result.is_a?(File)
    end
    if RUBY_VERSION[0,3] == "1.8"
      response["connection"] = 'close'
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
    if cert = request.client_cert and cn = Puppet::Util::SSL.cn_from_subject(cert.subject)
      result[:node] = cn
      result[:authenticated] = true
    else
      result[:node] = resolve_node(result)
    end

    result
  end
end
