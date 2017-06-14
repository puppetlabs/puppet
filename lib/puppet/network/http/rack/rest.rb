require 'openssl'
require 'cgi'
require 'puppet/network/http/handler'
require 'puppet/util/ssl'
require 'uri'

class Puppet::Network::HTTP::RackREST
  include Puppet::Network::HTTP::Handler

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
    register([Puppet::Network::HTTP::API.master_routes,
              Puppet::Network::HTTP::API.ca_routes,
              Puppet::Network::HTTP::API.not_found_upgrade])
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
    headers = request.env.select {|k,v| k.start_with? 'HTTP_'}.inject({}) do |m, (k,v)|
      m[k.sub(/^HTTP_/, '').gsub('_','-').downcase] = v
      m
    end
    headers['content-type'] = request.content_type
    headers
  end

  # Return which HTTP verb was used in this request.
  def http_method(request)
    request.request_method
  end

  # Return the query params for this request.
  def params(request)
    if request.post?
      params = request.params
    else
      # rack doesn't support multi-valued query parameters,
      # e.g. ignore, so parse them ourselves
      params = CGI.parse(request.query_string)
      convert_singular_arrays_to_value(params)
    end
    result = decode_params(params)
    result.merge(extract_client_info(request))
  end

  # what path was requested? (this is, without any query parameters)
  def path(request)
    # The value that Passenger provides for 'path' is escaped
    # (URL percent-encoded), see
    # https://github.com/phusion/passenger/blob/release-5.0.26/src/apache2_module/Hooks.cpp#L885
    # for the implementation as hooked up to an Apache web server.  Code
    # in the indirector / HTTP layer which consumes this path, however, assumes
    # that it has already been unescaped, so it is unescaped here.
    if request.path
      URI.unescape(request.path)
    end
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
    if cert.nil? || cert.empty?
      # When running with unicorn, the SSL_CLIENT_CERT variable is not available
      # in the environment, therefore we have to pass a header: 'X-SSL-Client-Cert'
      cert = request.env['HTTP_X_SSL_CLIENT_CERT']
      if cert.nil? || cert.empty?
        nil
      else
        # in contrast to the environment variable, the client cert is passed in
        # as single string, therefore restore the certificate to a valid pem
        # encoded certificate
        cert.gsub!(/ /, "\n")
        cert.gsub!(/BEGIN\nCERT/, "BEGIN CERT")
        cert.gsub!(/END\nCERT/, "END CERT")
        cert = Puppet::SSL::Certificate.from_instance(OpenSSL::X509::Certificate.new(cert))
        cert
      end
    else
      Puppet::SSL::Certificate.from_instance(OpenSSL::X509::Certificate.new(cert))
    end
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

  def convert_singular_arrays_to_value(hash)
    hash.each do |key, value|
      if value.size == 1
        hash[key] = value.first
      end
    end
  end
end
