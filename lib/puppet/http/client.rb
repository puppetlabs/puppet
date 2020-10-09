#
# @api private
#
# The client contains a pool of persistent HTTP connections and creates HTTP
# sessions.
#
class Puppet::HTTP::Client

  # @api private
  # @return [Puppet::HTTP::Pool] the pool instance associated with
  #   this client
  attr_reader :pool

  #
  # @api private
  #
  # Create a new http client instance. The client contains a pool of persistent
  # HTTP connections and creates HTTP sessions.
  #
  # @param [Puppet::HTTP::Pool] pool pool of persistent Net::HTTP
  #   connections
  # @param [Puppet::SSL::SSLContext] ssl_context ssl context to be used for
  #   connections
  # @param [Puppet::SSL::SSLContext] system_ssl_context the system ssl context
  #   used if :include_system_store is set to true
  # @param [Integer] redirect_limit default number of HTTP redirections to allow
  #   in a given request. Can also be specified per-request.
  # @param [Integer] retry_limit number of HTTP reties allowed in a given
  #   request
  #
  def initialize(pool: Puppet::HTTP::Pool.new(Puppet[:http_keepalive_timeout]), ssl_context: nil, system_ssl_context: nil, redirect_limit: 10, retry_limit: 100)
    @pool = pool
    @default_headers = {
      'X-Puppet-Version' => Puppet.version,
      'User-Agent' => Puppet[:http_user_agent],
    }.freeze
    @default_ssl_context = ssl_context
    @default_system_ssl_context = system_ssl_context
    @default_redirect_limit = redirect_limit
    @retry_after_handler = Puppet::HTTP::RetryAfterHandler.new(retry_limit, Puppet[:runinterval])
  end

  #
  # @api private
  #
  # Create a new HTTP session. A session is the object through which services
  # may be connected to and accessed.
  #
  # @return [Puppet::HTTP::Session] the newly created HTTP session
  #
  def create_session
    Puppet::HTTP::Session.new(self, build_resolvers)
  end

  #
  # @api private
  #
  # Open a connection to the given URI
  #
  # @param [URI] uri the connection destination
  # @param [Hash] options
  # @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #   be used for connections
  # @option options [Boolean] :include_system_store (false) if we should include
  #   the system store for connection
  #
  # @yield [Net::HTTP] If a block is given, yields an active http connection
  #   from the pool
  #
  def connect(uri, options: {}, &block)
    start = Time.now
    verifier = nil
    connected = false

    site = Puppet::HTTP::Site.from_uri(uri)
    if site.use_ssl?
      ssl_context = options.fetch(:ssl_context, nil)
      include_system_store = options.fetch(:include_system_store, false)
      ctx = resolve_ssl_context(ssl_context, include_system_store)
      verifier = Puppet::SSL::Verifier.new(site.host, ctx)
    end

    @pool.with_connection(site, verifier) do |http|
      connected = true
      if block_given?
        yield http
      end
    end
  rescue Net::OpenTimeout => e
    raise_error(_("Request to %{uri} timed out connect operation after %{elapsed} seconds") % {uri: uri, elapsed: elapsed(start)}, e, connected)
  rescue Net::ReadTimeout => e
    raise_error(_("Request to %{uri} timed out read operation after %{elapsed} seconds") % {uri: uri, elapsed: elapsed(start)}, e, connected)
  rescue EOFError => e
    raise_error(_("Request to %{uri} interrupted after %{elapsed} seconds") % {uri: uri, elapsed: elapsed(start)}, e, connected)
  rescue Puppet::SSL::SSLError
    raise
  rescue Puppet::HTTP::HTTPError
    raise
  rescue => e
    raise_error(_("Request to %{uri} failed after %{elapsed} seconds: %{message}") %
                {uri: uri, elapsed: elapsed(start), message: e.message}, e, connected)
  end

  #
  # @api private
  #
  # Submits a GET HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @param [Hash] options passed through to the request execution
  # @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #   be used for connections
  # @option options [Boolean] :include_system_store (false) if we should include
  #   the system store for connection
  # @param options [Integer] :redirect_limit number of HTTP redirections to allow
  #   for this request.
  #
  # @yield [Puppet::HTTP::Response] if a block is given yields the response
  #
  # @return [String] if a block is not given, returns the response body
  #
  def get(url, headers: {}, params: {}, options: {}, &block)
    url = encode_query(url, params)

    request = Net::HTTP::Get.new(url, @default_headers.merge(headers))

    execute_streaming(request, options: options) do |response|
      if block_given?
        yield response
      else
        response.body
      end
    end
  end

  #
  # @api private
  #
  # Submits a HEAD HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @param [Hash] options passed through to the request execution
  # @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #   be used for connections
  # @option options [Boolean] :include_system_store (false) if we should include
  #   the system store for connection
  # @param options [Integer] :redirect_limit number of HTTP redirections to allow
  #   for this request.
  #
  # @return [String] the body of the request response
  #
  def head(url, headers: {}, params: {}, options: {})
    url = encode_query(url, params)

    request = Net::HTTP::Head.new(url, @default_headers.merge(headers))

    execute_streaming(request, options: options) do |response|
      response.body
    end
  end

  #
  # @api private
  #
  # Submits a PUT HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [String] body the body of the PUT request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @param [Hash] options passed through to the request execution
  # @option options [String] :content_type the type of the body content
  # @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #   be used for connections
  # @option options [Boolean] :include_system_store (false) if we should include
  #   the system store for connection
  # @param options [Integer] :redirect_limit number of HTTP redirections to allow
  #   for this request.
  #
  # @return [String] the body of the request response
  #
  def put(url, body, headers: {}, params: {}, options: {})
    raise ArgumentError, "'put' requires a string 'body' argument" unless body.is_a?(String)
    url = encode_query(url, params)

    request = Net::HTTP::Put.new(url, @default_headers.merge(headers))
    request.body = body
    request.content_length = body.bytesize

    raise ArgumentError, "'put' requires a 'content-type' header" unless request['Content-Type']

    execute_streaming(request, options: options) do |response|
      response.body
    end
  end

  #
  # @api private
  #
  # Submits a POST HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [String] body the body of the POST request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @param [Hash] options passed through to the request execution
  # @option options [String] :content_type the type of the body content
  # @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #   be used for connections
  # @option options [Boolean] :include_system_store (false) if we should include
  #   the system store for connection
  # @param options [Integer] :redirect_limit number of HTTP redirections to allow
  #   for this request.
  #
  # @return [String] the body of the request response
  #
  def post(url, body, headers: {}, params: {}, options: {}, &block)
    raise ArgumentError, "'post' requires a string 'body' argument" unless body.is_a?(String)
    url = encode_query(url, params)

    request = Net::HTTP::Post.new(url, @default_headers.merge(headers))
    request.body = body
    request.content_length = body.bytesize

    raise ArgumentError, "'post' requires a 'content-type' header" unless request['Content-Type']

    execute_streaming(request, options: options) do |response|
      if block_given?
        yield response
      else
        response.body
      end
    end
  end

  #
  # @api private
  #
  # Submits a DELETE HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @param [Hash] options options hash passed through to the request execution
  # @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #   be used for connections
  # @option options [Boolean] :include_system_store (false) if we should include
  #   the system store for connection
  # @param options [Integer] :redirect_limit number of HTTP redirections to allow
  #   for this request.
  #
  # @return [String] the body of the request response
  #
  def delete(url, headers: {}, params: {}, options: {})
    url = encode_query(url, params)

    request = Net::HTTP::Delete.new(url, @default_headers.merge(headers))

    execute_streaming(request, options: options) do |response|
      response.body
    end
  end

  #
  # @api private
  #
  # Close persistent connections in the pool
  #
  def close
    @pool.close
  end

  protected

  def encode_query(url, params)
    return url if params.empty?

    url = url.dup
    url.query = encode_params(params)
    url
  end

  private

  def execute_streaming(request, options: {}, &block)
    redirector = Puppet::HTTP::Redirector.new(options.fetch(:redirect_limit, @default_redirect_limit))

    basic_auth = options.fetch(:basic_auth, nil)
    unless basic_auth
      if request.uri.user && request.uri.password
        basic_auth = { user: request.uri.user, password: request.uri.password }
      end
    end

    redirects = 0
    retries = 0
    response = nil
    done = false

    while !done do
      connect(request.uri, options: options) do |http|
        apply_auth(request, basic_auth)

        # don't call return within the `request` block
        http.request(request) do |nethttp|
          response = Puppet::HTTP::Response.new(nethttp, request.uri)
          begin
            Puppet.debug("HTTP #{request.method.upcase} #{request.uri} returned #{response.code} #{response.reason}")

            if redirector.redirect?(request, response)
              request = redirector.redirect_to(request, response, redirects)
              redirects += 1
              next
            elsif @retry_after_handler.retry_after?(request, response)
              interval = @retry_after_handler.retry_after_interval(request, response, retries)
              retries += 1
              if interval
                if http.started?
                  Puppet.debug("Closing connection for #{Puppet::HTTP::Site.from_uri(request.uri)}")
                  http.finish
                end
                Puppet.warning(_("Sleeping for %{interval} seconds before retrying the request") % { interval: interval })
                ::Kernel.sleep(interval)
                next
              end
            end

            yield response
          ensure
            response.drain
          end

          done = true
        end
      end
    end

    response
  end

  def expand_into_parameters(data)
    data.inject([]) do |params, key_value|
      key, value = key_value

      expanded_value = case value
                       when Array
                         value.collect { |val| [key, val] }
                       else
                         [key_value]
                       end

      params.concat(expand_primitive_types_into_parameters(expanded_value))
    end
  end

  def expand_primitive_types_into_parameters(data)
    data.inject([]) do |params, key_value|
      key, value = key_value
      case value
      when nil
        params
      when true, false, String, Symbol, Integer, Float
        params << [key, value]
      else
        raise Puppet::HTTP::SerializationError, _("HTTP REST queries cannot handle values of type '%{klass}'") % { klass: value.class }
      end
    end
  end

  def encode_params(params)
    params = expand_into_parameters(params)
    params.map do |key, value|
      "#{key}=#{Puppet::Util.uri_query_encode(value.to_s)}"
    end.join('&')
  end

  def elapsed(start)
    (Time.now - start).to_f.round(3)
  end

  def raise_error(message, cause, connected)
    if connected
      raise Puppet::HTTP::HTTPError.new(message, cause)
    else
      raise Puppet::HTTP::ConnectionError.new(message, cause)
    end
  end

  def resolve_ssl_context(ssl_context, include_system_store)
    if ssl_context
      raise Puppet::HTTP::HTTPError, "The ssl_context and include_system_store parameters are mutually exclusive" if include_system_store
      ssl_context
    elsif include_system_store
      system_ssl_context
    else
      @default_ssl_context || Puppet.lookup(:ssl_context)
    end
  end

  def system_ssl_context
    return @default_system_ssl_context if @default_system_ssl_context

    cert_provider = Puppet::X509::CertProvider.new
    cacerts = cert_provider.load_cacerts || []

    ssl = Puppet::SSL::SSLProvider.new
    @default_system_ssl_context = ssl.create_system_context(cacerts: cacerts)
  end

  def apply_auth(request, basic_auth)
    if basic_auth
      request.basic_auth(basic_auth[:user], basic_auth[:password])
    end
  end

  def build_resolvers
    resolvers = []

    if Puppet[:use_srv_records]
      resolvers << Puppet::HTTP::Resolver::SRV.new(self, domain: Puppet[:srv_domain])
    end

    server_list_setting = Puppet.settings.setting(:server_list)
    if server_list_setting.value && !server_list_setting.value.empty?
      # use server list to resolve all services
      services = Puppet::HTTP::Service::SERVICE_NAMES.dup

      # except if it's been explicitly set
      if Puppet.settings.set_by_config?(:ca_server)
        services.delete(:ca)
      end

      if Puppet.settings.set_by_config?(:report_server)
        services.delete(:report)
      end

      resolvers << Puppet::HTTP::Resolver::ServerList.new(self, server_list_setting: server_list_setting, default_port: Puppet[:masterport], services: services)
    end

    resolvers << Puppet::HTTP::Resolver::Settings.new(self)

    resolvers.freeze
  end
end
