class Puppet::Network::HTTP::ConnectionAdapter < Puppet::Network::HTTP::Connection
  def initialize(host, port, options = {})
    super(host, port, options)

    @client = Puppet.runtime[:http]
  end

  def get(path, headers = {}, options = {})
    headers ||= {}
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      resp = @client.get(to_url(path), headers: headers, options: options)
      resp.nethttp
    end
  end

  def post(path, data, headers = nil, options = {})
    headers ||= {}
    headers['Content-Type'] ||= "application/x-www-form-urlencoded"
    data ||= ''
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      resp = @client.post(to_url(path), data, headers: headers, options: options)
      resp.nethttp
    end
  end

  def head(path, headers = {}, options = {})
    headers ||= {}
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      resp = @client.head(to_url(path), headers: headers, options: options)
      resp.nethttp
    end
  end

  def delete(path, headers = {'Depth' => 'Infinity'}, options = {})
    headers ||= {}
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      resp = @client.delete(to_url(path), headers: headers, options: options)
      resp.nethttp
    end
  end

  def put(path, data, headers = nil, options = {})
    headers ||= {}
    headers['Content-Type'] ||= "application/x-www-form-urlencoded"
    data ||= ''
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      resp = @client.put(to_url(path), data, headers: headers, options: options)
      resp.nethttp
    end
  end

  def request_get(*args, &block)
    path, headers = *args
    headers ||= {}
    options = {
      ssl_context: resolve_ssl_context,
      redirect_limit: @redirect_limit
    }

    resp = @client.get(to_url(path), headers: headers, options: options) do |response|
      yield response.nethttp if block_given?
    end
    resp.nethttp
  end

  def request_head(*args, &block)
    path, headers = *args
    headers ||= {}
    options = {
      ssl_context: resolve_ssl_context,
      redirect_limit: @redirect_limit
    }

    response = @client.head(to_url(path), headers: headers, options: options)
    yield response.nethttp if block_given?
    response.nethttp
  end

  def request_post(*args, &block)
    path, data, headers = *args
    headers ||= {}
    headers['Content-Type'] ||= "application/x-www-form-urlencoded"
    options = {
      ssl_context: resolve_ssl_context,
      redirect_limit: @redirect_limit
    }

    resp = @client.post(to_url(path), data, headers: headers, options: options) do |response|
      yield response.nethttp if block_given?
    end
    resp.nethttp
  end

  private

  # The old Connection class ignores the ssl_context on the Puppet stack,
  # and always loads certs/keys based on what is currently in the filesystem.
  # If the files are missing, it would attempt to bootstrap the certs/keys
  # while in the process of making a network request, due to the call to
  # Puppet.lookup(:ssl_host) in Puppet::SSL::Validator::DefaultValidator#setup_connection.
  # This class doesn't preserve the boostrap behavior because that is handled
  # outside of this class, and can only be triggered by running `puppet ssl` or
  # `puppet agent`.
  def resolve_ssl_context
    # don't need an ssl context for http connections
    return nil unless @site.use_ssl?

    # if our verifier has an ssl_context, use that
    ctx = @verifier.ssl_context
    return ctx if ctx

    # load available certs
    cert = Puppet::X509::CertProvider.new
    ssl = Puppet::SSL::SSLProvider.new
    begin
      password = cert.load_private_key_password
      ssl.load_context(certname: Puppet[:certname], password: password)
    rescue Puppet::SSL::SSLError => e
      Puppet.log_exception(e)

      # if we don't have cacerts, then create a root context that doesn't
      # trust anything. The old code used to fallback to VERIFY_NONE,
      # which we don't want to emulate.
      ssl.create_root_context(cacerts: [])
    end
  end

  def to_url(path)
    if path =~ /^https?:\/\//
      # The old Connection class accepts a URL as the request path, and sends
      # it in "absolute-form" in the request line, e.g. GET https://puppet:8140/.
      # See https://httpwg.org/specs/rfc7230.html#absolute-form. It just so happens
      # to work because HTTP 1.1 servers are required to accept absolute-form even
      # though clients are only supposed to send them to proxies, so the proxy knows
      # what upstream server to CONNECT to. This method creates a URL using the
      # scheme/host/port that the connection was created with, and appends the path
      # portion of the absolute-form. The resulting request will use "origin-form"
      # as it should have done all along.
      url = URI(path)
      URI("#{@site.addr}/#{normalize_path(url.path)}")
    else
      URI("#{@site.addr}/#{Puppet::Util.uri_encode(normalize_path(path))}")
    end
  end

  def normalize_path(path)
    if path[0] == '/'
      path[1..-1]
    else
      path
    end
  end

  def with_error_handling(&block)
    yield
  rescue Puppet::HTTP::TooManyRedirects => e
    raise Puppet::Network::HTTP::RedirectionLimitExceededException.new(_("Too many HTTP redirections for %{host}:%{port}") % { host: @host, port: @port }, e)
  rescue Puppet::HTTP::HTTPError => e
    Puppet.log_exception(e, e.message)
    case e.cause
    when Net::OpenTimeout, Net::ReadTimeout, Net::HTTPError, EOFError
      raise e.cause
    else
      raise e
    end
  end
end
