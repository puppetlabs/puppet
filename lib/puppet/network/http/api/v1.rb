require 'puppet/network/authorization'

class Puppet::Network::HTTP::API::V1
  include Puppet::Network::Authorization

  # How we map http methods and the indirection name in the URI
  # to an indirection method.
  METHOD_MAP = {
    "GET" => {
      :plural => :search,
      :singular => :find
    },
    "POST" => {
      :singular => :find,
    },
    "PUT" => {
      :singular => :save
    },
    "DELETE" => {
      :singular => :destroy
    },
    "HEAD" => {
      :singular => :head
    }
  }

  def self.routes
    Puppet::Network::HTTP::Route.path(/.*/).any(new)
  end

  # handle an HTTP request
  def call(request, response)
    indirection_name, method, key, params = uri2indirection(request.method, request.path, request.params)
    certificate = request.client_cert

    check_authorization(method, "/#{indirection_name}/#{key}", params)

    indirection = Puppet::Indirector::Indirection.instance(indirection_name.to_sym)
    raise ArgumentError, "Could not find indirection '#{indirection_name}'" unless indirection

    if !indirection.allow_remote_requests?
      # TODO: should we tell the user we found an indirection but it doesn't
      # allow remote requests, or just pretend there's no handler at all? what
      # are the security implications for the former?
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("No handler for #{indirection.name}", :NO_INDIRECTION_REMOTE_REQUESTS)
    end

    trusted = Puppet::Context::TrustedInformation.remote(params[:authenticated], params[:node], certificate)
    Puppet.override(:trusted_information => trusted) do
      send("do_#{method}", indirection, key, params, request, response)
    end
  rescue Puppet::Network::HTTP::Error::HTTPError => e
    return do_http_control_exception(response, e)
  rescue Exception => e
    return do_exception(response, e)
  end

  def uri2indirection(http_method, uri, params)
    environment, indirection, key = uri.split("/", 4)[1..-1] # the first field is always nil because of the leading slash

    raise ArgumentError, "The environment must be purely alphanumeric, not '#{environment}'" unless Puppet::Node::Environment.valid_name?(environment)
    raise ArgumentError, "The indirection name must be purely alphanumeric, not '#{indirection}'" unless indirection =~ /^\w+$/

    method = indirection_method(http_method, indirection)

    configured_environment = Puppet.lookup(:environments).get(environment)
    if configured_environment.nil?
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("Could not find environment '#{environment}'", Puppet::Network::HTTP::Issues::ENVIRONMENT_NOT_FOUND)
    else
      configured_environment = configured_environment.override_from_commandline(Puppet.settings)
      params[:environment] = configured_environment
    end

    params.delete(:bucket_path)

    raise ArgumentError, "No request key specified in #{uri}" if key == "" or key.nil?

    key = URI.unescape(key)

    [indirection, method, key, params]
  end

  private

  def do_http_control_exception(response, exception)
    msg = exception.message
    Puppet.info(msg)
    response.respond_with(exception.status, "text/plain", msg)
  end

  def do_exception(response, exception, status=400)
    if exception.is_a?(Puppet::Network::AuthorizationError)
      # make sure we return the correct status code
      # for authorization issues
      status = 403 if status == 400
    end

    Puppet.log_exception(exception)

    response.respond_with(status, "text/plain", exception.to_s)
  end

  # Execute our find.
  def do_find(indirection, key, params, request, response)
    unless result = indirection.find(key, params)
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("Could not find #{indirection.name} #{key}", Puppet::Network::HTTP::Issues::RESOURCE_NOT_FOUND)
    end

    format = accepted_response_formatter_for(indirection.model, request)

    rendered_result = result
    if result.respond_to?(:render)
      Puppet::Util::Profiler.profile("Rendered result in #{format}", [:http, :v1_render, format]) do
        rendered_result = result.render(format)
      end
    end

    Puppet::Util::Profiler.profile("Sent response", [:http, :v1_response]) do
      response.respond_with(200, format, rendered_result)
    end
  end

  # Execute our head.
  def do_head(indirection, key, params, request, response)
    unless indirection.head(key, params)
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("Could not find #{indirection.name} #{key}", Puppet::Network::HTTP::Issues::RESOURCE_NOT_FOUND)
    end

    # No need to set a response because no response is expected from a
    # HEAD request.  All we need to do is not die.
  end

  # Execute our search.
  def do_search(indirection, key, params, request, response)
    result = indirection.search(key, params)

    if result.nil?
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("Could not find instances in #{indirection.name} with '#{key}'", Puppet::Network::HTTP::Issues::RESOURCE_NOT_FOUND)
    end

    format = accepted_response_formatter_for(indirection.model, request)

    response.respond_with(200, format, indirection.model.render_multiple(format, result))
  end

  # Execute our destroy.
  def do_destroy(indirection, key, params, request, response)
    formatter = accepted_response_formatter_or_yaml_for(indirection.model, request)

    result = indirection.destroy(key, params)

    response.respond_with(200, formatter, formatter.render(result))
  end

  # Execute our save.
  def do_save(indirection, key, params, request, response)
    formatter = accepted_response_formatter_or_yaml_for(indirection.model, request)
    sent_object = read_body_into_model(indirection.model, request)

    result = indirection.save(sent_object, key)

    response.respond_with(200, formatter, formatter.render(result))
  end

  def accepted_response_formatter_for(model_class, request)
    accepted_formats = request.headers['accept'] or raise Puppet::Network::HTTP::Error::HTTPNotAcceptableError.new("Missing required Accept header", Puppet::Network::HTTP::Issues::MISSING_HEADER_FIELD)
    request.response_formatter_for(model_class.supported_formats, accepted_formats)
  end

  def accepted_response_formatter_or_yaml_for(model_class, request)
    accepted_formats = request.headers['accept'] || "yaml"
    request.response_formatter_for(model_class.supported_formats, accepted_formats)
  end

  def read_body_into_model(model_class, request)
    data = request.body.to_s

    format = request.format
    model_class.convert_from(format, data)
  end

  def indirection_method(http_method, indirection)
    raise ArgumentError, "No support for http method #{http_method}" unless METHOD_MAP[http_method]

    unless method = METHOD_MAP[http_method][plurality(indirection)]
      raise ArgumentError, "No support for plurality #{plurality(indirection)} for #{http_method} operations"
    end

    method
  end

  def self.indirection2uri(request)
    indirection = request.method == :search ? pluralize(request.indirection_name.to_s) : request.indirection_name.to_s
    "/#{request.environment.to_s}/#{indirection}/#{request.escaped_key}#{request.query_string}"
  end

  def self.request_to_uri_and_body(request)
    indirection = request.method == :search ? pluralize(request.indirection_name.to_s) : request.indirection_name.to_s
    ["/#{request.environment.to_s}/#{indirection}/#{request.escaped_key}", request.query_string.sub(/^\?/,'')]
  end

  def self.pluralize(indirection)
    return(indirection == "status" ? "statuses" : indirection + "s")
  end

  def plurality(indirection)
    # NOTE This specific hook for facts is ridiculous, but it's a *many*-line
    # fix to not need this, and our goal is to move away from the complication
    # that leads to the fix being too long.
    return :singular if indirection == "facts"
    return :singular if indirection == "status"
    return :singular if indirection == "certificate_status"
    return :plural if indirection == "inventory"

    result = (indirection =~ /s$|_search$/) ? :plural : :singular

    indirection.sub!(/s$|_search$/, '')
    indirection.sub!(/statuse$/, 'status')

    result
  end
end
