# frozen_string_literal: true

module Puppet::HTTP
  # A base class for puppet http errors
  # @api public
  class HTTPError < Puppet::Error; end

  # A connection error such as if the server refuses the connection.
  # @api public
  class ConnectionError < HTTPError; end

  # A failure to route to the server such as if the `server_list` is exhausted.
  # @api public
  class RouteError < HTTPError; end

  # An HTTP protocol error, such as the server's response missing a required header.
  # @api public
  class ProtocolError < HTTPError; end

  # An error serializing or deserializing an object via REST.
  # @api public
  class SerializationError < HTTPError; end

  # An error due to an unsuccessful HTTP response, such as HTTP 500.
  # @api public
  class ResponseError < HTTPError
    attr_reader :response

    def initialize(response)
      super(response.reason)
      @response = response
    end
  end

  # An error if asked to follow too many redirects (such as HTTP 301).
  # @api public
  class TooManyRedirects < HTTPError
    def initialize(addr)
      super(_("Too many HTTP redirections for %{addr}") % { addr: addr })
    end
  end

  # An error if asked to retry (such as HTTP 503) too many times.
  # @api public
  class TooManyRetryAfters < HTTPError
    def initialize(addr)
      super(_("Too many HTTP retries for %{addr}") % { addr: addr })
    end
  end
end
