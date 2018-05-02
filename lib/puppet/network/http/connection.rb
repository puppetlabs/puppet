require 'net/https'
require 'puppet/ssl/host'
require 'puppet/ssl/validator'
require 'puppet/network/http'
require 'uri'
require 'date'
require 'time'

module Puppet::Network::HTTP

  # This will be raised if too many redirects happen for a given HTTP request
  class RedirectionLimitExceededException < Puppet::Error ; end

  # This class provides simple methods for issuing various types of HTTP
  # requests.  It's interface is intended to mirror Ruby's Net::HTTP
  # object, but it provides a few important bits of additional
  # functionality.  Notably:
  #
  # * Any HTTPS requests made using this class will use Puppet's SSL
  #   certificate configuration for their authentication, and
  # * Provides some useful error handling for any SSL errors that occur
  #   during a request.
  # @api public
  class Connection

    OPTION_DEFAULTS = {
      :use_ssl => true,
      :verify => nil,
      :redirect_limit => 10,
    }

    # Creates a new HTTP client connection to `host`:`port`.
    # @param host [String] the host to which this client will connect to
    # @param port [Integer] the port to which this client will connect to
    # @param options [Hash] options influencing the properties of the created
    #   connection,
    # @option options [Boolean] :use_ssl true to connect with SSL, false
    #   otherwise, defaults to true
    # @option options [#setup_connection] :verify An object that will configure
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
      @host = host
      @port = port

      unknown_options = options.keys - OPTION_DEFAULTS.keys
      raise Puppet::Error, _("Unrecognized option(s): %{opts}") % { opts: unknown_options.map(&:inspect).sort.join(', ') } unless unknown_options.empty?

      options = OPTION_DEFAULTS.merge(options)
      @use_ssl = options[:use_ssl]
      @verify = options[:verify]
      @redirect_limit = options[:redirect_limit]
      @site = Puppet::Network::HTTP::Site.new(@use_ssl ? 'https' : 'http', host, port)
      @pool = Puppet.lookup(:http_pool)
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
      do_request(Net::HTTP::Get.new(path, headers), options)
    end

    # @param path [String]
    # @param data [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def post(path, data, headers = nil, options = {})
      request = Net::HTTP::Post.new(path, headers)
      request.body = data
      do_request(request, options)
    end

    # @param path [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def head(path, headers = {}, options = {})
      do_request(Net::HTTP::Head.new(path, headers), options)
    end

    # @param path [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def delete(path, headers = {'Depth' => 'Infinity'}, options = {})
      do_request(Net::HTTP::Delete.new(path, headers), options)
    end

    # @param path [String]
    # @param data [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def put(path, data, headers = nil, options = {})
      request = Net::HTTP::Put.new(path, headers)
      request.body = data
      do_request(request, options)
    end

    def request(method, *args)
      self.send(method, *args)
    end

    # TODO: These are proxies for the Net::HTTP#request_* methods, which are
    # almost the same as the "get", "post", etc. methods that we've ported above,
    # but they are able to accept a code block and will yield to it, which is
    # necessary to stream responses, e.g. file content.  For now
    # we're not funneling these proxy implementations through our #request
    # method above, so they will not inherit the same error handling.  In the
    # future we may want to refactor these so that they are funneled through
    # that method and do inherit the error handling.
    def request_get(*args, &block)
      with_connection(@site) do |connection|
        connection.request_get(*args, &block)
      end
    end

    def request_head(*args, &block)
      with_connection(@site) do |connection|
        connection.request_head(*args, &block)
      end
    end

    def request_post(*args, &block)
      with_connection(@site) do |connection|
        connection.request_post(*args, &block)
      end
    end
    # end of Net::HTTP#request_* proxies

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

    private

    def do_request(request, options)
      current_request = request
      current_site = @site
      response = nil

      0.upto(@redirect_limit) do |redirection|
        return response if response

        with_connection(current_site) do |connection|
          apply_options_to(current_request, options)

          current_response = execute_request(connection, current_request)

          case current_response.code.to_i
          when 301, 302, 307
            # handle redirection
            location = URI.parse(current_response['location'])
            current_site = current_site.move_to(location)

            # update to the current request path
            current_request = current_request.class.new(location.path)
            current_request.body = request.body
            request.each do |header, value|
              current_request[header] = value
            end
          when 429, 503
            response = handle_retry_after(current_response)
          else
            response = current_response
          end
        end

        # and try again...
      end

      raise RedirectionLimitExceededException, _("Too many HTTP redirections for %{host}:%{port}") % { host: @host, port: @port }
    end

    # Handles the Retry-After header of a HTTPResponse
    #
    # This method checks the response for a Retry-After header and handles
    # it by sleeping for the indicated number of seconds. The response is
    # returned unmodified if no Retry-After header is present.
    #
    # @param response [Net::HTTPResponse] A response received from the
    #   HTTP client.
    #
    # @return [nil] Sleeps and returns nil if the response contained a
    #   Retry-After header that indicated the request should be retried.
    # @return [Net::HTTPResponse] Returns the `response` unmodified if
    #   no Retry-After header was present or the Retry-After header could
    #   not be parsed as an integer or RFC 2822 date.
    def handle_retry_after(response)
      retry_after = response['Retry-After']
      return response if retry_after.nil?

      retry_sleep = parse_retry_after_header(retry_after)
      # Recover remote hostname if Net::HTTPResponse was generated by a
      # method that fills in the uri attribute.
      #
      # TODO: Drop the respond_to? check when support for Ruby 1.9.3 is dropped.
      server_hostname = if response.respond_to?(:uri) && response.uri.is_a?(URI)
                          response.uri.host
                        else
                          # TRANSLATORS: Used in the phrase:
                          # "Received a response from the remote server."
                          _('the remote server')
                        end

      if retry_sleep.nil?
        Puppet.err(_('Received a %{status_code} response from %{server_hostname}, but the Retry-After header value of "%{retry_after}" could not be converted to an integer or RFC 2822 date.') %
                   {status_code: response.code,
                    server_hostname: server_hostname,
                    retry_after: retry_after.inspect})

        return response
      end

      # Cap maximum sleep at the run interval of the Puppet agent.
      retry_sleep = [retry_sleep, Puppet[:runinterval]].min

      Puppet.warning(_('Received a %{status_code} response from %{server_hostname}. Sleeping for %{retry_sleep} seconds before retrying the request.') %
                     {status_code: response.code,
                      server_hostname: server_hostname,
                      retry_sleep: retry_sleep})

      ::Kernel.sleep(retry_sleep)

      return nil
    end

    # Parse the value of a Retry-After header
    #
    # Parses a string containing an Integer or RFC 2822 datestamp and returns
    # an integer number of seconds before a request can be retried.
    #
    # @param header_value [String] The value of the Retry-After header.
    #
    # @return [Integer] Number of seconds to wait before retrying the
    #   request. Will be equal to 0 for the case of date that has already
    #   passed.
    # @return [nil] Returns `nil` when the `header_value` can't be
    #   parsed as an Integer or RFC 2822 date.
    def parse_retry_after_header(header_value)
      retry_after = begin
                      Integer(header_value)
                    rescue TypeError, ArgumentError
                      begin
                        DateTime.rfc2822(header_value)
                      rescue ArgumentError
                        return nil
                      end
                    end

      case retry_after
      when Integer
        retry_after
      when DateTime
        sleep = (retry_after.to_time - DateTime.now.to_time).to_i
        (sleep > 0) ? sleep : 0
      end
    end

    def apply_options_to(request, options)
      request["User-Agent"] = Puppet[:http_user_agent]

      if options[:basic_auth]
        request.basic_auth(options[:basic_auth][:user], options[:basic_auth][:password])
      end
    end

    def execute_request(connection, request)
      start = Time.now
      connection.request(request)
    rescue EOFError => e
      elapsed = (Time.now - start).to_f.round(3)
      uri = @site.addr + request.path.split('?')[0]
      eof = EOFError.new(_('request %{uri} interrupted after %{elapsed} seconds') % {uri: uri, elapsed: elapsed})
      eof.set_backtrace(e.backtrace) unless e.backtrace.empty?
      raise eof
    end

    def with_connection(site, &block)
      response = nil
      @pool.with_connection(site, @verify) do |conn|
        response = yield conn
      end
      response
    rescue OpenSSL::SSL::SSLError => error
      # can be nil
      peer_cert = @verify.peer_certs.last

      if error.message.include? "certificate verify failed"
        msg = error.message
        msg << ": [" + @verify.verify_errors.join('; ') + "]"
        raise Puppet::Error, msg, error.backtrace
      elsif peer_cert && !OpenSSL::SSL.verify_certificate_identity(peer_cert.content, site.host)
        valid_certnames = [peer_cert.name, *peer_cert.subject_alt_names].uniq
        if valid_certnames.size > 1
          expected_certnames = _("expected one of %{certnames}") % { certnames: valid_certnames.join(', ') }
        else
          expected_certnames = _("expected %{certname}") % { certname: valid_certnames.first }
        end

        msg = _("Server hostname '%{host}' did not match server certificate; %{expected_certnames}") % { host: site.host, expected_certnames: expected_certnames }
        raise Puppet::Error, msg, error.backtrace
      else
        raise
      end
    end
  end
end
