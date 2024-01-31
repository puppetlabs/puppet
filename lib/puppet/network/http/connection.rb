# frozen_string_literal: true

require_relative '../../../puppet/http'

# This will be raised if too many redirects happen for a given HTTP request
class Puppet::Network::HTTP::RedirectionLimitExceededException < Puppet::Error; end

# This class provides simple methods for issuing various types of HTTP
# requests.  It's interface is intended to mirror Ruby's Net::HTTP
# object, but it provides a few important bits of additional
# functionality.  Notably:
#
# * Any HTTPS requests made using this class will use Puppet's SSL
#   certificate configuration for their authentication, and
# * Provides some useful error handling for any SSL errors that occur
#   during a request.
#
# @deprecated Use {Puppet.runtime[:http]}
# @api public
class Puppet::Network::HTTP::Connection
  include Puppet::HTTP::ResponseConverter

  OPTION_DEFAULTS = {
    :use_ssl => true,
    :verifier => nil,
    :redirect_limit => 10,
  }

  # Creates a new HTTP client connection to `host`:`port`.
  # @param host [String] the host to which this client will connect to
  # @param port [Integer] the port to which this client will connect to
  # @param options [Hash] options influencing the properties of the created
  #   connection,
  # @option options [Boolean] :use_ssl true to connect with SSL, false
  #   otherwise, defaults to true
  # @option options [Puppet::SSL::Verifier] :verifier An object that will configure
  #   any verification to do on the connection
  # @option options [Integer] :redirect_limit the number of allowed
  #   redirections, defaults to 10 passing any other option in the options
  #   hash results in a Puppet::Error exception
  #
  # @note the HTTP connection itself happens lazily only when {#request}, or
  #   one of the {#get}, {#post}, {#delete}, {#head} or {#put} is called
  # @note The correct way to obtain a connection is to use one of the factory
  #   methods on {Puppet::Network::HttpPool}
  # @api private
  def initialize(host, port, options = {})
    unknown_options = options.keys - OPTION_DEFAULTS.keys
    raise Puppet::Error, _("Unrecognized option(s): %{opts}") % { opts: unknown_options.map(&:inspect).sort.join(', ') } unless unknown_options.empty?

    options = OPTION_DEFAULTS.merge(options)
    @use_ssl = options[:use_ssl]
    if @use_ssl
      unless options[:verifier].is_a?(Puppet::SSL::Verifier)
        raise ArgumentError, _("Expected an instance of Puppet::SSL::Verifier but was passed a %{klass}") % { klass: options[:verifier].class }
      end

      @verifier = options[:verifier]
    end
    @redirect_limit = options[:redirect_limit]
    @site = Puppet::HTTP::Site.new(@use_ssl ? 'https' : 'http', host, port)
    @client = Puppet.runtime[:http]
  end

  # The address to connect to.
  def address
    @site.host
  end

  # The port to connect to.
  def port
    @site.port
  end

  # Whether to use ssl
  def use_ssl?
    @site.use_ssl?
  end

  # @api private
  def verifier
    @verifier
  end

  # @!macro [new] common_options
  #   @param options [Hash] options influencing the request made. Any
  #   options not recognized by this class will be ignored - no error will
  #   be thrown.
  #   @option options [Hash{Symbol => String}] :basic_auth The basic auth
  #     :username and :password to use for the request, :metric_id Ignored
  #     by this class - used by Puppet Server only. The metric id by which
  #     to track metrics on requests.

  # @param path [String]
  # @param headers [Hash{String => String}]
  # @!macro common_options
  # @api public
  def get(path, headers = {}, options = {})
    headers ||= {}
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      to_ruby_response(@client.get(to_url(path), headers: headers, options: options))
    end
  end

  # @param path [String]
  # @param data [String]
  # @param headers [Hash{String => String}]
  # @!macro common_options
  # @api public
  def post(path, data, headers = nil, options = {})
    headers ||= {}
    headers['Content-Type'] ||= "application/x-www-form-urlencoded"
    data ||= ''
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      to_ruby_response(@client.post(to_url(path), data, headers: headers, options: options))
    end
  end

  # @param path [String]
  # @param headers [Hash{String => String}]
  # @!macro common_options
  # @api public
  def head(path, headers = {}, options = {})
    headers ||= {}
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      to_ruby_response(@client.head(to_url(path), headers: headers, options: options))
    end
  end

  # @param path [String]
  # @param headers [Hash{String => String}]
  # @!macro common_options
  # @api public
  def delete(path, headers = { 'Depth' => 'Infinity' }, options = {})
    headers ||= {}
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      to_ruby_response(@client.delete(to_url(path), headers: headers, options: options))
    end
  end

  # @param path [String]
  # @param data [String]
  # @param headers [Hash{String => String}]
  # @!macro common_options
  # @api public
  def put(path, data, headers = nil, options = {})
    headers ||= {}
    headers['Content-Type'] ||= "application/x-www-form-urlencoded"
    data ||= ''
    options[:ssl_context] ||= resolve_ssl_context
    options[:redirect_limit] ||= @redirect_limit

    with_error_handling do
      to_ruby_response(@client.put(to_url(path), data, headers: headers, options: options))
    end
  end

  def request_get(*args, &block)
    path, headers = *args
    headers ||= {}
    options = {
      ssl_context: resolve_ssl_context,
      redirect_limit: @redirect_limit
    }

    ruby_response = nil
    @client.get(to_url(path), headers: headers, options: options) do |response|
      ruby_response = to_ruby_response(response)
      yield ruby_response if block_given?
    end
    ruby_response
  end

  def request_head(*args, &block)
    path, headers = *args
    headers ||= {}
    options = {
      ssl_context: resolve_ssl_context,
      redirect_limit: @redirect_limit
    }

    response = @client.head(to_url(path), headers: headers, options: options)
    ruby_response = to_ruby_response(response)
    yield ruby_response if block_given?
    ruby_response
  end

  def request_post(*args, &block)
    path, data, headers = *args
    headers ||= {}
    headers['Content-Type'] ||= "application/x-www-form-urlencoded"
    options = {
      ssl_context: resolve_ssl_context,
      redirect_limit: @redirect_limit
    }

    ruby_response = nil
    @client.post(to_url(path), data, headers: headers, options: options) do |response|
      ruby_response = to_ruby_response(response)
      yield ruby_response if block_given?
    end
    ruby_response
  end

  private

  # Resolve the ssl_context based on the verifier associated with this
  # connection or load the available set of certs and key on disk.
  # Don't try to bootstrap the agent, as we only want that to be triggered
  # when running `puppet ssl` or `puppet agent`.
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
      # and query portions of the absolute-form. The resulting request will use "origin-form"
      # as it should have done all along.
      abs_form = URI(path)
      url = URI("#{@site.addr}/#{normalize_path(abs_form.path)}")
      url.query = abs_form.query if abs_form.query
      url
    else
      URI("#{@site.addr}/#{normalize_path(path)}")
    end
  end

  def normalize_path(path)
    if path[0] == '/'
      path[1..]
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
