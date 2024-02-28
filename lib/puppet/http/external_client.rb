# frozen_string_literal: true

# Adapts an external http_client_class to the HTTP client API. The former
# is typically registered by puppetserver and only implements a subset of
# the Puppet::Network::HTTP::Connection methods. As a result, only the
# `get` and `post` methods are supported. Calling `delete`, etc will
# raise a NotImplementedError.
#
# @api private
class Puppet::HTTP::ExternalClient < Puppet::HTTP::Client
  # Create an external http client.
  #
  # @param [Class] http_client_class The class to create to handle the request
  def initialize(http_client_class)
    @http_client_class = http_client_class
  end

  # (see Puppet::HTTP::Client#get)
  # @api private
  def get(url, headers: {}, params: {}, options: {}, &block)
    url = encode_query(url, params)

    options[:use_ssl] = url.scheme == 'https'

    client = @http_client_class.new(url.host, url.port, options)
    response = Puppet::HTTP::ResponseNetHTTP.new(url, client.get(url.request_uri, headers, options))

    if block_given?
      yield response
    else
      response
    end
  rescue Puppet::HTTP::HTTPError
    raise
  rescue => e
    raise Puppet::HTTP::HTTPError.new(e.message, e)
  end

  # (see Puppet::HTTP::Client#post)
  # @api private
  def post(url, body, headers: {}, params: {}, options: {}, &block)
    raise ArgumentError, "'post' requires a string 'body' argument" unless body.is_a?(String)

    url = encode_query(url, params)

    options[:use_ssl] = url.scheme == 'https'

    client = @http_client_class.new(url.host, url.port, options)
    response = Puppet::HTTP::ResponseNetHTTP.new(url, client.post(url.request_uri, body, headers, options))

    if block_given?
      yield response
    else
      response
    end
  rescue Puppet::HTTP::HTTPError, ArgumentError
    raise
  rescue => e
    raise Puppet::HTTP::HTTPError.new(e.message, e)
  end

  # (see Puppet::HTTP::Client#close)
  # @api private
  def close
    # This is a noop as puppetserver doesn't provide a way to close its http client.
  end

  # The following are intentionally not documented

  def create_session
    raise NotImplementedError
  end

  def connect(uri, options: {}, &block)
    raise NotImplementedError
  end

  def head(url, headers: {}, params: {}, options: {})
    raise NotImplementedError
  end

  def put(url, headers: {}, params: {}, options: {})
    raise NotImplementedError
  end

  def delete(url, headers: {}, params: {}, options: {})
    raise NotImplementedError
  end
end
