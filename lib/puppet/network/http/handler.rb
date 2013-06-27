module Puppet::Network::HTTP
end

require 'puppet/network/http'
require 'puppet/network/http/api/v1'
require 'puppet/network/authorization'
require 'puppet/network/authentication'
require 'puppet/network/rights'
require 'puppet/util/profiler'
require 'resolv'

module Puppet::Network::HTTP::Handler
  include Puppet::Network::HTTP::API::V1
  include Puppet::Network::Authorization
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
    def initialize(message)
      super("Not Acceptable: " + message, 406)
    end
  end

  class HTTPNotFoundError < HTTPError
    def initialize(message)
      super("Not Found: " + message, 404)
    end
  end

  attr_reader :server, :handler

  # Retrieve all headers from the http request, as a hash with the header names
  # (lower-cased) as the keys
  def headers(request)
    raise NotImplementedError
  end

  # Retrieve the accept header from the http request.
  def accept_header(request)
    raise NotImplementedError
  end

  # Retrieve the Content-Type header from the http request.
  def content_type_header(request)
    raise NotImplementedError
  end

  def request_format(request)
    if header = content_type_header(request)
      header.gsub!(/\s*;.*$/,'') # strip any charset
      format = Puppet::Network::FormatHandler.mime(header)
      raise "Client sent a mime-type (#{header}) that doesn't correspond to a format we support" if format.nil?
      report_if_deprecated(format)
      return format.name.to_s if format.suitable?
    end

    raise "No Content-Type header was received, it isn't possible to unserialize the request"
  end

  def format_to_mime(format)
    format.is_a?(Puppet::Network::Format) ? format.mime : format
  end

  def initialize_for_puppet(server)
    @server = server
  end

  # handle an HTTP request
  def process(request, response)
    request_headers = headers(request)
    request_params = params(request)
    request_method = http_method(request)
    request_path = path(request)

    configure_profiler(request_headers, request_params)

    Puppet::Util::Profiler.profile("Processed request #{request_method} #{request_path}") do
      indirection, method, key, params = uri2indirection(request_method, request_path, request_params)

      check_authorization(indirection, method, key, params)
      warn_if_near_expiration(client_cert(request))

      send("do_#{method}", indirection, key, params, request, response)
    end
  rescue SystemExit,NoMemoryError
    raise
  rescue HTTPError => e
    return do_exception(response, e.message, e.status)
  rescue Exception => e
    return do_exception(response, e)
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

  def do_exception(response, exception, status=400)
    if exception.is_a?(Puppet::Network::AuthorizationError)
      # make sure we return the correct status code
      # for authorization issues
      status = 403 if status == 400
    end

    if exception.is_a?(Exception)
      Puppet.log_exception(exception)
    else
      Puppet.notice(exception.to_s)
    end

    set_content_type(response, "text/plain")
    set_response(response, exception.to_s, status)
  end

  def model(indirection_name)
    raise ArgumentError, "Could not find indirection '#{indirection_name}'" unless indirection = Puppet::Indirector::Indirection.instance(indirection_name.to_sym)
    indirection.model
  end

  # Execute our find.
  def do_find(indirection_name, key, params, request, response)
    model_class = model(indirection_name)
    unless result = model_class.indirection.find(key, params)
      raise HTTPNotFoundError, "Could not find #{indirection_name} #{key}"
    end

    format = accepted_response_formatter_for(model_class, request)
    set_content_type(response, format)

    rendered_result = result
    if result.respond_to?(:render)
      Puppet::Util::Profiler.profile("Rendered result in #{format}") do
        rendered_result = result.render(format)
      end
    end

    Puppet::Util::Profiler.profile("Sent response") do
      set_response(response, rendered_result)
    end
  end

  # Execute our head.
  def do_head(indirection_name, key, params, request, response)
    unless self.model(indirection_name).indirection.head(key, params)
      raise HTTPNotFoundError, "Could not find #{indirection_name} #{key}"
    end

    # No need to set a response because no response is expected from a
    # HEAD request.  All we need to do is not die.
  end

  # Execute our search.
  def do_search(indirection_name, key, params, request, response)
    model  = self.model(indirection_name)
    result = model.indirection.search(key, params)

    if result.nil?
      raise HTTPNotFoundError, "Could not find instances in #{indirection_name} with '#{key}'"
    end

    format = accepted_response_formatter_for(model, request)
    set_content_type(response, format)

    set_response(response, model.render_multiple(format, result))
  end

  # Execute our destroy.
  def do_destroy(indirection_name, key, params, request, response)
    model_class = model(indirection_name)
    formatter = accepted_response_formatter_or_yaml_for(model_class, request)

    result = model_class.indirection.destroy(key, params)

    set_content_type(response, formatter)
    set_response(response, formatter.render(result))
  end

  # Execute our save.
  def do_save(indirection_name, key, params, request, response)
    model_class = model(indirection_name)
    formatter = accepted_response_formatter_or_yaml_for(model_class, request)
    sent_object = read_body_into_model(model_class, request)

    result = model_class.indirection.save(sent_object, key)

    set_content_type(response, formatter)
    set_response(response, formatter.render(result))
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

  def report_if_deprecated(format)
    if format.name == :yaml || format.name == :b64_zlib_yaml
      Puppet.deprecation_warning("YAML in network requests is deprecated and will be removed in a future version. See http://links.puppetlabs.com/deprecate_yaml_on_network")
    end
  end

  def accepted_response_formatter_for(model_class, request)
    accepted_formats = accept_header(request) or raise HTTPNotAcceptableError, "Missing required Accept header"
    response_formatter_for(model_class, request, accepted_formats)
  end

  def accepted_response_formatter_or_yaml_for(model_class, request)
    accepted_formats = accept_header(request) || "yaml"
    response_formatter_for(model_class, request, accepted_formats)
  end

  def response_formatter_for(model_class, request, accepted_formats)
    formatter = Puppet::Network::FormatHandler.most_suitable_format_for(
      accepted_formats.split(/\s*,\s*/),
      model_class.supported_formats)

    if formatter.nil?
      raise HTTPNotAcceptableError, "No supported formats are acceptable (Accept: #{accepted_formats})"
    end

    report_if_deprecated(formatter)
    formatter
  end

  def read_body_into_model(model_class, request)
    data = body(request).to_s
    raise ArgumentError, "No data to save" if !data or data.empty?

    format = request_format(request)
    model_class.convert_from(format, data)
  end

  def get?(request)
    http_method(request) == 'GET'
  end

  def put?(request)
    http_method(request) == 'PUT'
  end

  def delete?(request)
    http_method(request) == 'DELETE'
  end

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
