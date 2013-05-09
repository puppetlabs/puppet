require 'net/http'
require 'uri'

require 'puppet/network/http_pool'
require 'puppet/network/http/api/v1'
require 'puppet/network/http/compression'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
  include Puppet::Network::HTTP::API::V1
  include Puppet::Network::HTTP::Compression.module

  class << self
    attr_reader :server_setting, :port_setting
  end

  # Specify the setting that we should use to get the server name.
  def self.use_server_setting(setting)
    @server_setting = setting
  end

  def self.server
    Puppet.settings[server_setting || :server]
  end

  # Specify the setting that we should use to get the port.
  def self.use_port_setting(setting)
    @port_setting = setting
  end

  def self.port
    Puppet.settings[port_setting || :masterport].to_i
  end

  # Provide appropriate headers.
  def headers
    add_accept_encoding({"Accept" => model.supported_formats.join(", ")})
  end

  def network(request)
    Puppet::Network::HttpPool.http_instance(request.server || self.class.server, request.port || self.class.port)
  end

  [:get, :post, :head, :delete, :put].each do |method|
    define_method "http_#{method}" do |request, *args|
      http_request(method, request, *args)
    end
  end

  def http_request(method, request, *args)
    http_connection = network(request)
    peer_certs = []
    verify_errors = []

    http_connection.verify_callback = proc do |preverify_ok, ssl_context|
      # We use the callback to collect the certificates for use in constructing
      # the error message if the verification failed.  This is necessary since we
      # don't have direct access to the cert that we expected the connection to
      # use otherwise.
      peer_certs << Puppet::SSL::Certificate.from_s(ssl_context.current_cert.to_pem)
      # And also keep the detailed verification error if such an error occurs
      if ssl_context.error_string and not preverify_ok
        verify_errors << "#{ssl_context.error_string} for #{ssl_context.current_cert.subject}"
      end
      preverify_ok
    end

    http_connection.send(method, *args)
  rescue OpenSSL::SSL::SSLError => error
    if error.message.include? "certificate verify failed"
      msg = error.message
      msg << ": [" + verify_errors.join('; ') + "]"
      raise Puppet::Error, msg
    elsif error.message =~ /hostname (was )?not match/
      raise unless cert = peer_certs.find { |c| c.name !~ /^puppet ca/i }

      valid_certnames = [cert.name, *cert.subject_alt_names].uniq
      msg = valid_certnames.length > 1 ? "one of #{valid_certnames.join(', ')}" : valid_certnames.first

      raise Puppet::Error, "Server hostname '#{http_connection.address}' did not match server certificate; expected #{msg}"
    elsif error.message.empty?
      # This may be because the server is speaking SSLv2 and we
      # monkey patch OpenSSL::SSL:SSLContext to reject SSLv2.
      raise error.exception("#{error.class} with no message")
    else
      raise
    end
  end

  def find(request)
    uri, body = request_to_uri_and_body(request)
    uri_with_query_string = "#{uri}?#{body}"
    # WEBrick in Ruby 1.9.1 only supports up to 1024 character lines in an HTTP request
    # http://redmine.ruby-lang.org/issues/show/3991
    response = if "GET #{uri_with_query_string} HTTP/1.1\r\n".length > 1024
      http_post(request, uri, body, headers)
    else
      http_get(request, uri_with_query_string, headers)
    end

    if is_http_200?(response)
      content_type, body = parse_response(response)
      result = deserialize_find(content_type, body)
      result.name = request.key if result.respond_to?(:name=)
      result
    else
      nil
    end
  end

  def head(request)
    response = http_head(request, indirection2uri(request), headers)

    !!is_http_200?(response)
  end

  def search(request)
    response = http_get(request, indirection2uri(request), headers)

    if is_http_200?(response)
      content_type, body = parse_response(response)
      deserialize_search(content_type, body) || []
    else
      []
    end
  end

  def destroy(request)
    raise ArgumentError, "DELETE does not accept options" unless request.options.empty?

    response = http_delete(request, indirection2uri(request), headers)

    if is_http_200?(response)
      content_type, body = parse_response(response)
      deserialize_destroy(content_type, body)
    else
      nil
    end
  end

  def save(request)
    raise ArgumentError, "PUT does not accept options" unless request.options.empty?

    response = http_put(request, indirection2uri(request), request.instance.render, headers.merge({ "Content-Type" => request.instance.mime }))

    if is_http_200?(response)
      content_type, body = parse_response(response)
      deserialize_save(content_type, body)
    else
      nil
    end
  end

  def validate_key(request)
    # Validation happens on the remote end
  end

  private

  def is_http_200?(response)
    case response.code
    when "404"
      false
    when /^2/
      true
    else
      # Raise the http error if we didn't get a 'success' of some kind.
      raise convert_to_http_error(response)
    end
  end

  def convert_to_http_error(response)
    message = "Error #{response.code} on SERVER: #{(response.body||'').empty? ? response.message : uncompress_body(response)}"
    Net::HTTPError.new(message, response)
  end

  # Returns the content_type, stripping any appended charset, and the
  # body, decompressed if necessary (content-encoding is checked inside
  # uncompress_body)
  def parse_response(response)
    if response['content-type']
      [ response['content-type'].gsub(/\s*;.*$/,''),
        body = uncompress_body(response) ]
    else
      raise "No content type in http response; cannot parse"
    end
  end

  def deserialize_find(content_type, body)
    model.convert_from(content_type, body)
  end

  def deserialize_search(content_type, body)
    model.convert_from_multiple(content_type, body)
  end

  def deserialize_destroy(content_type, body)
    model.convert_from(content_type, body)
  end

  def deserialize_save(content_type, body)
    nil
  end

  def environment
    Puppet::Node::Environment.new
  end
end
