require 'net/http'
require 'uri'

require 'puppet/network/http'
require 'puppet/network/http_pool'
require 'puppet/network/http/api/v1'
require 'puppet/network/http/compression'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
  include Puppet::Network::HTTP::Compression.module

  class << self
    attr_reader :server_setting, :port_setting
  end

  # Specify the setting that we should use to get the server name.
  def self.use_server_setting(setting)
    @server_setting = setting
  end

  # Specify the setting that we should use to get the port.
  def self.use_port_setting(setting)
    @port_setting = setting
  end

  # Specify the service to use when doing SRV record lookup
  def self.use_srv_service(service)
    @srv_service = service
  end

  def self.srv_service
    @srv_service || :puppet
  end

  def self.server
    Puppet.settings[server_setting || :server]
  end

  def self.port
    Puppet.settings[port_setting || :masterport].to_i
  end

  # Provide appropriate headers.
  def headers
    add_accept_encoding({"Accept" => model.supported_formats.join(", ")})
  end

  def add_profiling_header(headers)
    if (Puppet[:profile])
      headers[Puppet::Network::HTTP::HEADER_ENABLE_PROFILING] = "true"
    end
    headers
  end

  def network(request)
    Puppet::Network::HttpPool.http_instance(request.server || self.class.server,
                                            request.port || self.class.port)
  end

  def http_get(request, path, headers = nil, *args)
    http_request(:get, request, path, add_profiling_header(headers), *args)
  end

  def http_post(request, path, data, headers = nil, *args)
    http_request(:post, request, path, data, add_profiling_header(headers), *args)
  end

  def http_head(request, path, headers = nil, *args)
    http_request(:head, request, path, add_profiling_header(headers), *args)
  end

  def http_delete(request, path, headers = nil, *args)
    http_request(:delete, request, path, add_profiling_header(headers), *args)
  end

  def http_put(request, path, data, headers = nil, *args)
    http_request(:put, request, path, data, add_profiling_header(headers), *args)
  end

  def http_request(method, request, *args)
    conn = network(request)
    conn.send(method, *args)
  end

  def find(request)
    uri, body = Puppet::Network::HTTP::API::V1.request_to_uri_and_body(request)
    uri_with_query_string = "#{uri}?#{body}"

    response = do_request(request) do |request|
      # WEBrick in Ruby 1.9.1 only supports up to 1024 character lines in an HTTP request
      # http://redmine.ruby-lang.org/issues/show/3991
      if "GET #{uri_with_query_string} HTTP/1.1\r\n".length > 1024
        http_post(request, uri, body, headers)
      else
        http_get(request, uri_with_query_string, headers)
      end
    end

    if is_http_200?(response)
      check_master_version(response)
      content_type, body = parse_response(response)
      result = deserialize_find(content_type, body)
      result.name = request.key if result.respond_to?(:name=)
      result

    elsif is_http_404?(response)
      return nil unless request.options[:fail_on_404]

      # 404 can get special treatment as the indirector API can not produce a meaningful
      # reason to why something is not found - it may not be the thing the user is
      # expecting to find that is missing, but something else (like the environment).
      # While this way of handling the issue is not perfect, there is at least an error
      # that makes a user aware of the reason for the failure.
      #
      content_type, body = parse_response(response)
      msg = "Find #{elide(uri_with_query_string, 100)} resulted in 404 with the message: #{body}"
      raise Puppet::Error, msg
    else
      nil
    end
  end

  def head(request)
    response = do_request(request) do |request|
      http_head(request, Puppet::Network::HTTP::API::V1.indirection2uri(request), headers)
    end

    if is_http_200?(response)
      check_master_version(response)
      true
    else
      false
    end
  end

  def search(request)
    response = do_request(request) do |request|
      http_get(request, Puppet::Network::HTTP::API::V1.indirection2uri(request), headers)
    end

    if is_http_200?(response)
      check_master_version(response)
      content_type, body = parse_response(response)
      deserialize_search(content_type, body) || []
    else
      []
    end
  end

  def destroy(request)
    raise ArgumentError, "DELETE does not accept options" unless request.options.empty?

    response = do_request(request) do |request|
      http_delete(request, Puppet::Network::HTTP::API::V1.indirection2uri(request), headers)
    end

    if is_http_200?(response)
      check_master_version(response)
      content_type, body = parse_response(response)
      deserialize_destroy(content_type, body)
    else
      nil
    end
  end

  def save(request)
    raise ArgumentError, "PUT does not accept options" unless request.options.empty?

    response = do_request(request) do |request|
      http_put(request, Puppet::Network::HTTP::API::V1.indirection2uri(request), request.instance.render, headers.merge({ "Content-Type" => request.instance.mime }))
    end

    if is_http_200?(response)
      check_master_version(response)
      content_type, body = parse_response(response)
      deserialize_save(content_type, body)
    else
      nil
    end
  end

  # Encapsulate call to request.do_request with the arguments from this class
  # Then yield to the code block that was called in
  # We certainly could have retained the full request.do_request(...) { |r| ... }
  # but this makes the code much cleaner and we only then actually make the call
  # to request.do_request from here, thus if we change what we pass or how we
  # get it, we only need to change it here.
  def do_request(request)
    request.do_request(self.class.srv_service, self.class.server, self.class.port) { |request| yield(request) }
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

  def is_http_404?(response)
    response.code == "404"
  end

  def convert_to_http_error(response)
    message = "Error #{response.code} on SERVER: #{(response.body||'').empty? ? response.message : uncompress_body(response)}"
    Net::HTTPError.new(message, response)
  end

  def check_master_version response
    if !response[Puppet::Network::HTTP::HEADER_PUPPET_VERSION] &&
       (Puppet[:legacy_query_parameter_serialization] == false || Puppet[:report_serialization_format] != "yaml")
      Puppet.notice "Using less secure serialization of reports and query parameters for compatibility"
      Puppet.notice "with older puppet master. To remove this notice, please upgrade your master(s) "
      Puppet.notice "to Puppet 3.3 or newer."
      Puppet.notice "See http://links.puppetlabs.com/deprecate_yaml_on_network for more information."
      Puppet[:legacy_query_parameter_serialization] = true
      Puppet[:report_serialization_format] = "yaml"
    end
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

  def elide(string, length)
    if Puppet::Util::Log.level == :debug || string.length <= length
      string
    else
      string[0, length - 3] + "..."
    end
  end
end
