module Puppet::Network::HTTP
end

require 'puppet/network/http/api/v1'
require 'puppet/network/rest_authorization'
require 'puppet/network/rights'
require 'resolv'

module Puppet::Network::HTTP::Handler
  include Puppet::Network::HTTP::API::V1
  include Puppet::Network::RestAuthorization

  attr_reader :server, :handler

  # Retrieve the accept header from the http request.
  def accept_header(request)
    raise NotImplementedError
  end

  # Retrieve the Content-Type header from the http request.
  def content_type_header(request)
    raise NotImplementedError
  end

  # Which format to use when serializing our response or interpreting the request.
  # IF the client provided a Content-Type use this, otherwise use the Accept header
  # and just pick the first value.
  def format_to_use(request)
    unless header = accept_header(request)
      raise ArgumentError, "An Accept header must be provided to pick the right format"
    end

    format = nil
    header.split(/,\s*/).each do |name|
      next unless format = Puppet::Network::FormatHandler.format(name)
      next unless format.suitable?
      return format
    end

    raise "No specified acceptable formats (#{header}) are functional on this machine"
  end

  def request_format(request)
    if header = content_type_header(request)
      header.gsub!(/\s*;.*$/,'') # strip any charset
      format = Puppet::Network::FormatHandler.mime(header)
      raise "Client sent a mime-type (#{header}) that doesn't correspond to a format we support" if format.nil?
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
    indirection, method, key, params = uri2indirection(http_method(request), path(request), params(request))

    check_authorization(indirection, method, key, params)

    send("do_#{method}", indirection, key, params, request, response)
  rescue SystemExit,NoMemoryError
    raise
  rescue Exception => e
    return do_exception(response, e)
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
      puts exception.backtrace if Puppet[:trace]
      Puppet.err(exception)
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
    unless result = model(indirection_name).indirection.find(key, params)
      Puppet.info("Could not find #{indirection_name} for '#{key}'")
      return do_exception(response, "Could not find #{indirection_name} #{key}", 404)
    end

    # The encoding of the result must include the format to use,
    # and it needs to be used for both the rendering and as
    # the content type.
    format = format_to_use(request)
    set_content_type(response, format)

    if result.respond_to?(:render)
      set_response(response, result.render(format))
    else
      set_response(response, result)
    end
  end

  # Execute our head.
  def do_head(indirection_name, key, params, request, response)
    unless self.model(indirection_name).indirection.head(key, params)
      Puppet.info("Could not find #{indirection_name} for '#{key}'")
      return do_exception(response, "Could not find #{indirection_name} #{key}", 404)
    end

    # No need to set a response because no response is expected from a
    # HEAD request.  All we need to do is not die.
  end

  # Execute our search.
  def do_search(indirection_name, key, params, request, response)
    model  = self.model(indirection_name)
    result = model.indirection.search(key, params)

    if result.nil?
      return do_exception(response, "Could not find instances in #{indirection_name} with '#{key}'", 404)
    end

    format = format_to_use(request)
    set_content_type(response, format)

    set_response(response, model.render_multiple(format, result))
  end

  # Execute our destroy.
  def do_destroy(indirection_name, key, params, request, response)
    result = model(indirection_name).indirection.destroy(key, params)

    return_yaml_response(response, result)
  end

  # Execute our save.
  def do_save(indirection_name, key, params, request, response)
    data = body(request).to_s
    raise ArgumentError, "No data to save" if !data or data.empty?

    format = request_format(request)
    obj = model(indirection_name).convert_from(format, data)
    result = model(indirection_name).indirection.save(obj, key)
    return_yaml_response(response, result)
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

  def return_yaml_response(response, body)
    set_content_type(response, Puppet::Network::FormatHandler.format("yaml"))
    set_response(response, body.to_yaml)
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

  def decode_params(params)
    params.inject({}) do |result, ary|
      param, value = ary
      next result if param.nil? || param.empty?

      param = param.to_sym

      # These shouldn't be allowed to be set by clients
      # in the query string, for security reasons.
      next result if param == :node
      next result if param == :ip
      value = CGI.unescape(value)
      if value =~ /^---/
        value = YAML.load(value)
      else
        value = true if value == "true"
        value = false if value == "false"
        value = Integer(value) if value =~ /^\d+$/
        value = value.to_f if value =~ /^\d+\.\d+$/
      end
      result[param] = value
      result
    end
  end
end
