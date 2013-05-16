require 'openssl'
require 'puppet/network/http/handler'
require 'puppet/network/http/rack/httphandler'
require 'puppet/util/ssl'

class Puppet::Network::HTTP::RackREST < Puppet::Network::HTTP::RackHttpHandler

  include Puppet::Network::HTTP::Handler

  HEADER_ACCEPT = 'HTTP_ACCEPT'.freeze
  ContentType = 'Content-Type'.freeze

  CHUNK_SIZE = 8192

  class RackFile
    def initialize(file)
      @file = file
    end

    def each
      while chunk = @file.read(CHUNK_SIZE)
        yield chunk
      end
    end

    def close
      @file.close
    end
  end

  def initialize(args={})
    super()
    initialize_for_puppet(args)
  end

  def set_content_type(response, format)
    response[ContentType] = format_to_mime(format)
  end

  # produce the body of the response
  def set_response(response, result, status = 200)
    response.status = status
    unless result.is_a?(File)
      response.write result
    else
      response["Content-Length"] = result.stat.size.to_s
      response.body = RackFile.new(result)
    end
  end

  # Retrieve all headers from the http request, as a map.
  def headers(request)
    request.env.select {|k,v| k.start_with? 'HTTP_'}.inject({}) do |m, (k,v)|
      m[k.sub(/^HTTP_/, '').downcase] = v
      m
    end
  end

  # Retrieve the accept header from the http request.
  def accept_header(request)
    request.env[HEADER_ACCEPT]
  end

  # Retrieve the accept header from the http request.
  def content_type_header(request)
    request.content_type
  end

  # Return which HTTP verb was used in this request.
  def http_method(request)
    request.request_method
  end

  # Return the query params for this request.
  def params(request)
    result = decode_params(request.params)
    result.merge(extract_client_info(request))
  end

  # what path was requested? (this is, without any query parameters)
  def path(request)
    request.path
  end

  # return the request body
  def body(request)
    request.body.read
  end

  def client_cert(request)
    # This environment variable is set by mod_ssl, note that it
    # requires the `+ExportCertData` option in the `SSLOptions` directive
    cert = request.env['SSL_CLIENT_CERT']
    # NOTE: The SSL_CLIENT_CERT environment variable will be the empty string
    # when Puppet agent nodes have not yet obtained a signed certificate.
    return nil if cert.nil? or cert.empty?
    OpenSSL::X509::Certificate.new(cert)
  end

  # Passenger freaks out if we finish handling the request without reading any
  # part of the body, so make sure we have.
  def cleanup(request)
    request.body.read(1)
    nil
  end

  def extract_client_info(request)
    result = {}
    result[:ip] = request.ip

    # if we find SSL info in the headers, use them to get a hostname from the CN.
    # try this with :ssl_client_header, which defaults should work for
    # Apache with StdEnvVars.
    subj_str = request.env[Puppet[:ssl_client_header]]
    subject = Puppet::Util::SSL.subject_from_dn(subj_str || "")

    if cn = Puppet::Util::SSL.cn_from_subject(subject)
      result[:node] = cn
      result[:authenticated] = (request.env[Puppet[:ssl_client_verify_header]] == 'SUCCESS')
    else
      result[:node] = resolve_node(result)
      result[:authenticated] = false
    end

    result
  end

end
