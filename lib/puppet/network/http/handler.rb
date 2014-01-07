module Puppet::Network::HTTP
end

require 'puppet/network/http'
require 'puppet/network/http/api/v1'
require 'puppet/network/authentication'
require 'puppet/network/rights'
require 'puppet/util/profiler'
require 'resolv'

module Puppet::Network::HTTP::Handler
  include Puppet::Network::Authentication

  # These shouldn't be allowed to be set by clients
  # in the query string, for security reasons.
  DISALLOWED_KEYS = ["node", "ip"]

  class HTTPError < Exception
    attr_reader :status

    def initialize(message, status)
      super(message)
      @status = status
    end
  end

  class HTTPNotAcceptableError < HTTPError
    CODE = 406
    def initialize(message)
      super("Not Acceptable: " + message, CODE)
    end
  end

  class HTTPNotFoundError < HTTPError
    CODE = 404
    def initialize(message)
      super("Not Found: " + message, CODE)
    end
  end

  class HTTPNotAuthorizedError < HTTPError
    CODE = 403
    def initialize(message)
      super("Not Authorized: " + message, CODE)
    end
  end

  attr_reader :server, :handler

  # Retrieve all headers from the http request, as a hash with the header names
  # (lower-cased) as the keys
  def headers(request)
    raise NotImplementedError
  end

  def format_to_mime(format)
    format.is_a?(Puppet::Network::Format) ? format.mime : format
  end

  Request = Struct.new(:headers, :params, :method, :path, :client_cert, :body) do
    def self.from_hash(hash)
      symbol_members = members.collect(&:intern)
      unknown = hash.keys - symbol_members
      if unknown.empty?
        new(*(symbol_members.collect { |m| hash[m] }))
      else
        raise ArgumentError, "Unknown arguments: #{unknown.collect(&:inspect).join(', ')}"
      end
    end

    def format
      if header = headers['content-type']
        header.gsub!(/\s*;.*$/,'') # strip any charset
        format = Puppet::Network::FormatHandler.mime(header)
        if format.nil?
          raise "Client sent a mime-type (#{header}) that doesn't correspond to a format we support"
        else
          report_if_deprecated(format)
          return format.name.to_s if format.suitable?
        end
      end

      raise "No Content-Type header was received, it isn't possible to unserialize the request"
    end

    def response_formatter_for(supported_formats, accepted_formats = headers['accept'])
      formatter = Puppet::Network::FormatHandler.most_suitable_format_for(
        accepted_formats.split(/\s*,\s*/),
        supported_formats)

      if formatter.nil?
        raise HTTPNotAcceptableError, "No supported formats are acceptable (Accept: #{accepted_formats})"
      end

      report_if_deprecated(formatter)

      formatter
    end

    def report_if_deprecated(format)
      if format.name == :yaml || format.name == :b64_zlib_yaml
        Puppet.deprecation_warning("YAML in network requests is deprecated and will be removed in a future version. See http://links.puppetlabs.com/deprecate_yaml_on_network")
      end
    end
  end

  class Response
    def initialize(handler, response)
      @handler = handler
      @response = response
    end

    def respond_with(code, type, body)
      @handler.set_content_type(@response, type)
      @handler.set_response(@response, body, code)
    end
  end

  class MemoryResponse
    attr_reader :code, :type, :body

    def respond_with(code, type, body)
      @code = code
      @type = type
      @body = body
    end
  end

  # handle an HTTP request
  def process(request, response)
    new_response = Response.new(self, response)

    request_headers = headers(request)
    request_params = params(request)
    request_method = http_method(request)
    request_path = path(request)

    new_request = Request.new(request_headers, request_params, request_method, request_path, client_cert(request), body(request))

    response[Puppet::Network::HTTP::HEADER_PUPPET_VERSION] = Puppet.version

    configure_profiler(request_headers, request_params)
    warn_if_near_expiration(new_request.client_cert)

    if request_path == "/v2/environments"
      raise HTTPNotAuthorizedError, "You shall not pass!"
      check_authorization(request_method, request_path, request_params)
    else
      Puppet::Util::Profiler.profile("Processed request #{request_method} #{request_path}") do
        Puppet::Network::HTTP::API::V1.new.process(new_request, new_response)
      end
    end
  rescue HTTPError => e
    msg = e.message
    Puppet.info(msg)
    new_response.respond_with(e.status, "text/plain", msg)
  rescue Exception => e
    msg = e.message
    Puppet.err(msg)
    new_response.respond_with(500, "text/plain", msg)
  ensure
    cleanup(request)
  end

  # Set the response up, with the body and status.
  def set_response(response, body, status = 200)
    raise NotImplementedError
  end

  # Set the specified format as the content type of the response.
  def set_content_type(response, format)
    raise NotImplementedError
  end

  # resolve node name from peer's ip address
  # this is used when the request is unauthenticated
  def resolve_node(result)
    begin
      return Resolv.getname(result[:ip])
    rescue => detail
      Puppet.err "Could not resolve #{result[:ip]}: #{detail}"
    end
    result[:ip]
  end

  private

  # methods to be overridden by the including web server class

  def http_method(request)
    raise NotImplementedError
  end

  def path(request)
    raise NotImplementedError
  end

  def request_key(request)
    raise NotImplementedError
  end

  def body(request)
    raise NotImplementedError
  end

  def params(request)
    raise NotImplementedError
  end

  def client_cert(request)
    raise NotImplementedError
  end

  def cleanup(request)
    # By default, there is nothing to cleanup.
  end

  def decode_params(params)
    params.select { |key, _| allowed_parameter?(key) }.inject({}) do |result, ary|
      param, value = ary
      result[param.to_sym] = parse_parameter_value(param, value)
      result
    end
  end

  def allowed_parameter?(name)
    not (name.nil? || name.empty? || DISALLOWED_KEYS.include?(name))
  end

  def parse_parameter_value(param, value)
    case value
    when /^---/
      Puppet.debug("Found YAML while processing request parameter #{param} (value: <#{value}>)")
      Puppet.deprecation_warning("YAML in network requests is deprecated and will be removed in a future version. See http://links.puppetlabs.com/deprecate_yaml_on_network")
      YAML.load(value, :safe => true, :deserialize_symbols => true)
    when Array
      value.collect { |v| parse_primitive_parameter_value(v) }
    else
      parse_primitive_parameter_value(value)
    end
  end

  def parse_primitive_parameter_value(value)
    case value
    when "true"
      true
    when "false"
      false
    when /^\d+$/
      Integer(value)
    when /^\d+\.\d+$/
      value.to_f
    else
      value
    end
  end

  def configure_profiler(request_headers, request_params)
    if (request_headers.has_key?(Puppet::Network::HTTP::HEADER_ENABLE_PROFILING.downcase) or Puppet[:profile])
      Puppet::Util::Profiler.current = Puppet::Util::Profiler::WallClock.new(Puppet.method(:debug), request_params.object_id)
    else
      Puppet::Util::Profiler.current = Puppet::Util::Profiler::NONE
    end
  end
end
