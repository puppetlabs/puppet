module Puppet::Network::HTTP
end

require 'puppet/network/http'
require 'puppet/network/rights'
require 'puppet/util/profiler'
require 'puppet/util/profiler/aggregate'
require 'resolv'

module Puppet::Network::HTTP::Handler
  include Puppet::Network::HTTP::Issues

  # These shouldn't be allowed to be set by clients
  # in the query string, for security reasons.
  DISALLOWED_KEYS = ["node", "ip"]

  def register(routes)
    # There's got to be a simpler way to do this, right?
    dupes = {}
    routes.each { |r| dupes[r.path_matcher] = (dupes[r.path_matcher] || 0) + 1 }
    dupes = dupes.collect { |pm, count| pm if count > 1 }.compact
    if dupes.count > 0
      raise ArgumentError, _("Given multiple routes with identical path regexes: %{regexes}") % { regexes: dupes.map{ |rgx| rgx.inspect }.join(', ') }
    end

    @routes = routes
    Puppet.debug("Routes Registered:")
    @routes.each do |route|
      Puppet.debug(route.inspect)
    end
  end

  # Retrieve all headers from the http request, as a hash with the header names
  # (lower-cased) as the keys
  def headers(request)
    raise NotImplementedError
  end

  # The mime type is always passed to the `set_content_type` method, so
  # it is no longer necessary to retrieve the Format's mime type.
  #
  # @deprecated
  def format_to_mime(format)
    format.is_a?(Puppet::Network::Format) ? format.mime : format
  end

  # Create a generic puppet request from the implementation-specific request
  # created by the web server
  def make_generic_request(request)
    request_path = path(request)

    Puppet::Network::HTTP::Request.new(
      headers(request),
      params(request),
      http_method(request),
      request_path, # path
      request_path, # routing_path
      client_cert(request),
      body(request)
    )
  end

  def with_request_profiling(request)
    profiler = configure_profiler(request.headers, request.params)

    Puppet::Util::Profiler.profile(
      _("Processed request %{request_method} %{request_path}") % { request_method: request.method, request_path: request.path },
      [:http, request.method, request.path]
    ) do
      yield
    end
  ensure
    remove_profiler(profiler) if profiler
  end

  # handle an HTTP request
  def process(external_request, response)
    # The response_wrapper stores the response and modifies it as a side effect.
    # The caller will use the original response
    response_wrapper = Puppet::Network::HTTP::Response.new(self, response)
    request = make_generic_request(external_request)

    set_puppet_version_header(response)

    respond_to_errors(response_wrapper) do
      with_request_profiling(request) do
        find_route_or_raise(request).process(request, response_wrapper)
      end
    end
  end

  def respond_to_errors(response)
    yield
  rescue Puppet::Network::HTTP::Error::HTTPError => e
    Puppet.info(e.message)
    respond_with_http_error(response, e)
  rescue StandardError => e
    http_e = Puppet::Network::HTTP::Error::HTTPServerError.new(e)
    Puppet.err([http_e.message, *e.backtrace].join("\n"))
    respond_with_http_error(response, http_e)
  end

  def respond_with_http_error(response, exception)
    response.respond_with(exception.status, "application/json", exception.to_json)
  end

  def find_route_or_raise(request)
    if route = @routes.find { |r| r.matches?(request) }
      return route
    else
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new(
              _("No route for %{request} %{path}") % { request: request.method, path: request.path },
              HANDLER_NOT_FOUND)
    end
  end

  def set_puppet_version_header(response)
    response[Puppet::Network::HTTP::HEADER_PUPPET_VERSION] = Puppet.version
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
      Puppet.err _("Could not resolve %{ip}: %{detail}") % { ip: result[:ip], detail: detail }
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
    if value.is_a?(Array)
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
      Puppet::Util::Profiler.add_profiler(Puppet::Util::Profiler::Aggregate.new(Puppet.method(:info), request_params.object_id))
    end
  end

  def remove_profiler(profiler)
    profiler.shutdown
    Puppet::Util::Profiler.remove_profiler(profiler)
  end
end
