require 'net/https'
require 'puppet/ssl/host'
require 'puppet/ssl/configuration'
require 'puppet/ssl/validator'
require 'puppet/network/http'
require 'uri'

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
    # @param port [Fixnum] the port to which this client will connect to
    # @param options [Hash] options influencing the properties of the created
    #   connection,
    # @option options [Boolean] :use_ssl true to connect with SSL, false
    #   otherwise, defaults to true
    # @option options [#setup_connection] :verify An object that will configure
    #   any verification to do on the connection
    # @option options [Fixnum] :redirect_limit the number of allowed
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
      raise Puppet::Error, "Unrecognized option(s): #{unknown_options.map(&:inspect).sort.join(', ')}" unless unknown_options.empty?

      options = OPTION_DEFAULTS.merge(options)
      @use_ssl = options[:use_ssl]
      @verify = options[:verify]
      @redirect_limit = options[:redirect_limit]
      @site = Puppet::Network::HTTP::Site.new(@use_ssl ? 'https' : 'http', host, port)
      @pool = Puppet.lookup(:http_pool)
    end

    # @!macro [new] common_options
    #   @param options [Hash] options influencing the request made
    #   @option options [Hash{Symbol => String}] :basic_auth The basic auth
    #     :username and :password to use for the request

    # @param path [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def get(path, headers = {}, options = {})
      request_with_redirects(Net::HTTP::Get.new(path, headers), options)
    end

    # @param path [String]
    # @param data [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def post(path, data, headers = nil, options = {})
      request = Net::HTTP::Post.new(path, headers)
      request.body = data
      request_with_redirects(request, options)
    end

    # @param path [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def head(path, headers = {}, options = {})
      request_with_redirects(Net::HTTP::Head.new(path, headers), options)
    end

    # @param path [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def delete(path, headers = {'Depth' => 'Infinity'}, options = {})
      request_with_redirects(Net::HTTP::Delete.new(path, headers), options)
    end

    # @param path [String]
    # @param data [String]
    # @param headers [Hash{String => String}]
    # @!macro common_options
    # @api public
    def put(path, data, headers = nil, options = {})
      request = Net::HTTP::Put.new(path, headers)
      request.body = data
      request_with_redirects(request, options)
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

    def request_with_redirects(request, options)
      current_request = request
      current_site = @site
      response = nil

      0.upto(@redirect_limit) do |redirection|
        return response if response

        with_connection(current_site) do |connection|
          apply_options_to(current_request, options)

          current_response = execute_request(connection, current_request)

          if [301, 302, 307].include?(current_response.code.to_i)

            # handle the redirection
            location = URI.parse(current_response['location'])
            current_site = current_site.move_to(location)

            # update to the current request path
            current_request = current_request.class.new(location.path)
            current_request.body = request.body
            request.each do |header, value|
              current_request[header] = value
            end
          else
            response = current_response
          end
        end

        # and try again...
      end

      raise RedirectionLimitExceededException, "Too many HTTP redirections for #{@host}:#{@port}"
    end

    def apply_options_to(request, options)
      if options[:basic_auth]
        request.basic_auth(options[:basic_auth][:user], options[:basic_auth][:password])
      end
    end

    def execute_request(connection, request)
      connection.request(request)
    end

    def with_connection(site, &block)
      response = nil
      @pool.with_connection(site, @verify) do |conn|
        response = yield conn
      end
      response
    rescue OpenSSL::SSL::SSLError => error
      if error.message.include? "certificate verify failed"
        msg = error.message
        msg << ": [" + @verify.verify_errors.join('; ') + "]"
        raise Puppet::Error, msg, error.backtrace
      elsif error.message =~ /hostname.*not match.*server certificate/
        leaf_ssl_cert = @verify.peer_certs.last

        valid_certnames = [leaf_ssl_cert.name, *leaf_ssl_cert.subject_alt_names].uniq
        msg = valid_certnames.length > 1 ? "one of #{valid_certnames.join(', ')}" : valid_certnames.first
        msg = "Server hostname '#{site.host}' did not match server certificate; expected #{msg}"

        raise Puppet::Error, msg, error.backtrace
      else
        raise
      end
    end
  end
end
