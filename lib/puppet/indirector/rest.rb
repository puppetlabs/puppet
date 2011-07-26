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

  # Figure out the content type, turn that into a format, and use the format
  # to extract the body of the response.
  def deserialize(response, multiple = false)
    case response.code
    when "404"
      return nil
    when /^2/
      raise "No content type in http response; cannot parse" unless response['content-type']

      content_type = response['content-type'].gsub(/\s*;.*$/,'') # strip any appended charset

      body = uncompress_body(response)

      # Convert the response to a deserialized object.
      if multiple
        model.convert_from_multiple(content_type, body)
      else
        model.convert_from(content_type, body)
      end
    else
      # Raise the http error if we didn't get a 'success' of some kind.
      raise convert_to_http_error(response)
    end
  end

  def convert_to_http_error(response)
    message = "Error #{response.code} on SERVER: #{(response.body||'').empty? ? response.message : uncompress_body(response)}"
    Net::HTTPError.new(message, response)
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

    # We add the callback to collect the certificates for use in constructing
    # the error message if the verification failed.  This is necessary since we
    # don't have direct access to the cert that we expected the connection to
    # use otherwise.
    #
    http_connection.verify_callback = proc do |preverify_ok, ssl_context|
      peer_certs << Puppet::SSL::Certificate.from_s(ssl_context.current_cert.to_pem)
      preverify_ok
    end

    http_connection.send(method, *args)
  rescue OpenSSL::SSL::SSLError => error
    if error.message.include? "certificate verify failed"
      raise Puppet::Error, "#{error.message}.  This is often because the time is out of sync on the server or client"
    elsif error.message.include? "hostname was not match"
      raise unless cert = peer_certs.find { |c| c.name !~ /^puppet ca/i }

      valid_certnames = [cert.name, *cert.alternate_names].uniq
      msg = valid_certnames.length > 1 ? "one of #{valid_certnames.join(', ')}" : valid_certnames.first

      raise Puppet::Error, "Server hostname '#{http_connection.address}' did not match server certificate; expected #{msg}"
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
    result = deserialize response
    result.name = request.key if result.respond_to?(:name=)
    result
  end

  def head(request)
    response = http_head(request, indirection2uri(request), headers)
    case response.code
    when "404"
      return false
    when /^2/
      return true
    else
      # Raise the http error if we didn't get a 'success' of some kind.
      raise convert_to_http_error(response)
    end
  end

  def search(request)
    unless result = deserialize(http_get(request, indirection2uri(request), headers), true)
      return []
    end
    result
  end

  def destroy(request)
    raise ArgumentError, "DELETE does not accept options" unless request.options.empty?
    deserialize http_delete(request, indirection2uri(request), headers)
  end

  def save(request)
    raise ArgumentError, "PUT does not accept options" unless request.options.empty?
    deserialize http_put(request, indirection2uri(request), request.instance.render, headers.merge({ "Content-Type" => request.instance.mime }))
  end

  private

  def environment
    Puppet::Node::Environment.new
  end
end
