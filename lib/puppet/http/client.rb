# frozen_string_literal: true

# The HTTP client provides methods for making `GET`, `POST`, etc requests to
# HTTP(S) servers. It also provides methods for resolving Puppetserver REST
# service endpoints using SRV records and settings (such as `server_list`,
# `server`, `ca_server`, etc). Once a service endpoint has been resolved, there
# are methods for making REST requests (such as getting a node, sending facts,
# etc).
#
# The client uses persistent HTTP connections by default unless the `Connection:
# close` header is specified and supports streaming response bodies.
#
# By default the client only trusts the Puppet CA for HTTPS connections. However,
# if the `include_system_store` request option is set to true, then Puppet will
# trust certificates in the puppet-agent CA bundle.
#
# @example To access the HTTP client:
#   client = Puppet.runtime[:http]
#
# @example To make an HTTP GET request:
#   response = client.get(URI("http://www.example.com"))
#
# @example To make an HTTPS GET request, trusting the puppet CA and certs in Puppet's CA bundle:
#   response = client.get(URI("https://www.example.com"), options: { include_system_store: true })
#
# @example To use a URL containing special characters, such as spaces:
#  response = client.get(URI(Puppet::Util.uri_encode("https://www.example.com/path to file")))
#
# @example To pass query parameters:
#   response = client.get(URI("https://www.example.com"), query: {'q' => 'puppet'})
#
# @example To pass custom headers:
#   response = client.get(URI("https://www.example.com"), headers: {'Accept-Content' => 'application/json'})
#
# @example To check if the response is successful (2xx):
#   response = client.get(URI("http://www.example.com"))
#   puts response.success?
#
# @example To get the response code and reason:
#   response = client.get(URI("http://www.example.com"))
#   unless response.success?
#     puts "HTTP #{response.code} #{response.reason}"
#    end
#
# @example To read response headers:
#   response = client.get(URI("http://www.example.com"))
#   puts response['Content-Type']
#
# @example To stream the response body:
#   client.get(URI("http://www.example.com")) do |response|
#     if response.success?
#       response.read_body do |data|
#         puts data
#       end
#     end
#   end
#
# @example To handle exceptions:
#   begin
#     client.get(URI("https://www.example.com"))
#   rescue Puppet::HTTP::ResponseError => e
#     puts "HTTP #{e.response.code} #{e.response.reason}"
#   rescue Puppet::HTTP::ConnectionError => e
#     puts "Connection error #{e.message}"
#   rescue Puppet::SSL::SSLError => e
#     puts "SSL error #{e.message}"
#   rescue Puppet::HTTP::HTTPError => e
#     puts "General HTTP error #{e.message}"
#   end
#
# @example To route to the `:puppet` service:
#   session = client.create_session
#   service = session.route_to(:puppet)
#
# @example To make a node request:
#   node = service.get_node(Puppet[:certname], environment: 'production')
#
# @example To submit facts:
#   facts = Puppet::Indirection::Facts.indirection.find(Puppet[:certname])
#   service.put_facts(Puppet[:certname], environment: 'production', facts: facts)
#
# @example To submit a report to the `:report` service:
#   report = Puppet::Transaction::Report.new
#   service = session.route_to(:report)
#   service.put_report(Puppet[:certname], report, environment: 'production')
#
# @api public
class Puppet::HTTP::Client
  attr_reader :pool

  # Create a new http client instance. Use `Puppet.runtime[:http]` to get
  # the current client instead of creating an instance of this class.
  #
  # @param [Puppet::HTTP::Pool] pool pool of persistent Net::HTTP
  #   connections
  # @param [Puppet::SSL::SSLContext] ssl_context ssl context to be used for
  #   connections
  # @param [Puppet::SSL::SSLContext] system_ssl_context the system ssl context
  #   used if :include_system_store is set to true
  # @param [Integer] redirect_limit default number of HTTP redirections to allow
  #   in a given request. Can also be specified per-request.
  # @param [Integer] retry_limit number of HTTP retries allowed in a given
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

  # Create a new HTTP session. A session is the object through which services
  # may be connected to and accessed.
  #
  # @return [Puppet::HTTP::Session] the newly created HTTP session
  #
  # @api public
  def create_session
    Puppet::HTTP::Session.new(self, build_resolvers)
  end

  # Open a connection to the given URI. It is typically not necessary to call
  # this method as the client will create connections as needed when a request
  # is made.
  #
  # @param [URI] uri the connection destination
  # @param [Hash] options
  # @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #   be used for connections
  # @option options [Boolean] :include_system_store (false) if we should include
  #   the system store for connection
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
    raise_error(_("Request to %{uri} timed out connect operation after %{elapsed} seconds") % { uri: uri, elapsed: elapsed(start) }, e, connected)
  rescue Net::ReadTimeout => e
    raise_error(_("Request to %{uri} timed out read operation after %{elapsed} seconds") % { uri: uri, elapsed: elapsed(start) }, e, connected)
  rescue EOFError => e
    raise_error(_("Request to %{uri} interrupted after %{elapsed} seconds") % { uri: uri, elapsed: elapsed(start) }, e, connected)
  rescue Puppet::SSL::SSLError
    raise
  rescue Puppet::HTTP::HTTPError
    raise
  rescue => e
    raise_error(_("Request to %{uri} failed after %{elapsed} seconds: %{message}") %
                { uri: uri, elapsed: elapsed(start), message: e.message }, e, connected)
  end

  # These options apply to all HTTP request methods
  #
  # @!macro [new] request_options
  #   @param [Hash] options HTTP request options. Options not recognized by the
  #     HTTP implementation will be ignored.
  #   @option options [Puppet::SSL::SSLContext] :ssl_context (nil) ssl context to
  #     be used for connections
  #   @option options [Boolean] :include_system_store (false) if we should include
  #     the system store for connection
  #   @option options [Integer] :redirect_limit (10) The maximum number of HTTP
  #     redirections to allow for this request.
  #   @option options [Hash] :basic_auth A map of `:username` => `String` and
  #     `:password` => `String`
  #   @option options [String] :metric_id The metric id used to track metrics
  #     on requests.

  # Submits a GET HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @!macro request_options
  #
  # @yield [Puppet::HTTP::Response] if a block is given yields the response
  #
  # @return [Puppet::HTTP::Response] the response
  #
  # @api public
  def get(url, headers: {}, params: {}, options: {}, &block)
    url = encode_query(url, params)

    request = Net::HTTP::Get.new(url, @default_headers.merge(headers))

    execute_streaming(request, options: options, &block)
  end

  # Submits a HEAD HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @!macro request_options
  #
  # @return [Puppet::HTTP::Response] the response
  #
  # @api public
  def head(url, headers: {}, params: {}, options: {})
    url = encode_query(url, params)

    request = Net::HTTP::Head.new(url, @default_headers.merge(headers))

    execute_streaming(request, options: options)
  end

  # Submits a PUT HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [String] body the body of the PUT request
  # @param [Hash] headers merged with the default headers defined by the client. The
  #   `Content-Type` header is required and should correspond to the type of data passed
  #   as the `body` argument.
  # @param [Hash] params encoded and set as the url query
  # @!macro request_options
  #
  # @return [Puppet::HTTP::Response] the response
  #
  # @api public
  def put(url, body, headers: {}, params: {}, options: {})
    raise ArgumentError, "'put' requires a string 'body' argument" unless body.is_a?(String)

    url = encode_query(url, params)

    request = Net::HTTP::Put.new(url, @default_headers.merge(headers))
    request.body = body
    request.content_length = body.bytesize

    raise ArgumentError, "'put' requires a 'content-type' header" unless request['Content-Type']

    execute_streaming(request, options: options)
  end

  # Submits a POST HTTP request to the given url
  #
  # @param [URI] url the location to submit the http request
  # @param [String] body the body of the POST request
  # @param [Hash] headers merged with the default headers defined by the client. The
  #   `Content-Type` header is required and should correspond to the type of data passed
  #   as the `body` argument.
  # @param [Hash] params encoded and set as the url query
  # @!macro request_options
  #
  # @yield [Puppet::HTTP::Response] if a block is given yields the response
  #
  # @return [Puppet::HTTP::Response] the response
  #
  # @api public
  def post(url, body, headers: {}, params: {}, options: {}, &block)
    raise ArgumentError, "'post' requires a string 'body' argument" unless body.is_a?(String)

    url = encode_query(url, params)

    request = Net::HTTP::Post.new(url, @default_headers.merge(headers))
    request.body = body
    request.content_length = body.bytesize

    raise ArgumentError, "'post' requires a 'content-type' header" unless request['Content-Type']

    execute_streaming(request, options: options, &block)
  end

  # Submits a DELETE HTTP request to the given url.
  #
  # @param [URI] url the location to submit the http request
  # @param [Hash] headers merged with the default headers defined by the client
  # @param [Hash] params encoded and set as the url query
  # @!macro request_options
  #
  # @return [Puppet::HTTP::Response] the response
  #
  # @api public
  def delete(url, headers: {}, params: {}, options: {})
    url = encode_query(url, params)

    request = Net::HTTP::Delete.new(url, @default_headers.merge(headers))

    execute_streaming(request, options: options)
  end

  # Close persistent connections in the pool.
  #
  # @return [void]
  #
  # @api public
  def close
    @pool.close
    @default_ssl_context = nil
    @default_system_ssl_context = nil
  end

  def default_ssl_context
    cert = Puppet::X509::CertProvider.new
    password = cert.load_private_key_password

    ssl = Puppet::SSL::SSLProvider.new
    ctx = ssl.load_context(certname: Puppet[:certname], password: password)
    ssl.print(ctx)
    ctx
  rescue => e
    # TRANSLATORS: `message` is an already translated string of why SSL failed to initialize
    Puppet.log_exception(e, _("Failed to initialize SSL: %{message}") % { message: e.message })
    # TRANSLATORS: `puppet agent -t` is a command and should not be translated
    Puppet.err(_("Run `puppet agent -t`"))
    raise e
  end

  protected

  def encode_query(url, params)
    return url if params.empty?

    url = url.dup
    url.query = encode_params(params)
    url
  end

  private

  # Connect or borrow a connection from the pool to the host and port associated
  # with the request's URL. Then execute the HTTP request, retrying and
  # following redirects as needed, and return the HTTP response. The response
  # body will always be fully drained/consumed when this method returns.
  #
  # If a block is provided, then the response will be yielded to the caller,
  # allowing the response body to be streamed.
  #
  # If the request/response did not result in an exception and the caller did
  # not ask for the connection to be closed (via Connection: close), then the
  # connection will be returned to the pool.
  #
  # @yieldparam [Puppet::HTTP::Response] response The final response, after
  # following redirects and retrying
  # @return [Puppet::HTTP::Response]
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

    until done do
      connect(request.uri, options: options) do |http|
        apply_auth(request, basic_auth) if redirects.zero?

        # don't call return within the `request` block
        close_and_sleep = nil
        http.request(request) do |nethttp|
          response = Puppet::HTTP::ResponseNetHTTP.new(request.uri, nethttp)
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
                close_and_sleep = proc do
                  if http.started?
                    Puppet.debug("Closing connection for #{Puppet::HTTP::Site.from_uri(request.uri)}")
                    http.finish
                  end
                  Puppet.warning(_("Sleeping for %{interval} seconds before retrying the request") % { interval: interval })
                  ::Kernel.sleep(interval)
                end
                next
              end
            end

            if block_given?
              yield response
            else
              response.body
            end
          ensure
            # we need to make sure the response body is fully consumed before
            # the connection is put back in the pool, otherwise the response
            # for one request could leak into a future response.
            response.drain
          end

          done = true
        end
      ensure
        # If a server responded with a retry, make sure the connection is closed and then
        # sleep the specified time.
        close_and_sleep.call if close_and_sleep
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
    @default_system_ssl_context = ssl.create_system_context(cacerts: cacerts, include_client_cert: true)
    ssl.print(@default_system_ssl_context)
    @default_system_ssl_context
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

      resolvers << Puppet::HTTP::Resolver::ServerList.new(self, server_list_setting: server_list_setting, default_port: Puppet[:serverport], services: services)
    end

    resolvers << Puppet::HTTP::Resolver::Settings.new(self)

    resolvers.freeze
  end
end
