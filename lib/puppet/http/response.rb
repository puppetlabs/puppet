# frozen_string_literal: true

# Represents the response returned from the server from an HTTP request.
#
# @api abstract
# @api public
class Puppet::HTTP::Response
  # @return [URI] the response url
  attr_reader :url

  # Create a response associated with the URL.
  #
  # @param [URI] url
  # @param [Integer] HTTP status
  # @param [String] HTTP reason
  def initialize(url, code, reason)
    @url = url
    @code = code
    @reason = reason
  end

  # Return the response code.
  #
  # @return [Integer] Response code for the request
  #
  # @api public
  def code
    @code
  end

  # Return the response message.
  #
  # @return [String] Response message for the request
  #
  # @api public
  def reason
    @reason
  end

  # Returns the entire response body. Can be used instead of
  #   `Puppet::HTTP::Response.read_body`, but both methods cannot be used for the
  #   same response.
  #
  # @return [String] Response body for the request
  #
  # @api public
  def body
    raise NotImplementedError
  end

  # Streams the response body to the caller in chunks. Can be used instead of
  #   `Puppet::HTTP::Response.body`, but both methods cannot be used for the same
  #   response.
  #
  # @yield [String] Streams the response body in chunks
  #
  # @raise [ArgumentError] raise if a block is not given
  #
  # @api public
  def read_body(&block)
    raise NotImplementedError
  end

  # Check if the request received a response of success (HTTP 2xx).
  #
  # @return [Boolean] Returns true if the response indicates success
  #
  # @api public
  def success?
    200 <= @code && @code < 300
  end

  # Get a header case-insensitively.
  #
  # @param [String] name The header name
  # @return [String] The header value
  #
  # @api public
  def [](name)
    raise NotImplementedError
  end

  # Yield each header name and value. Returns an enumerator if no block is given.
  #
  # @yieldparam [String] header name
  # @yieldparam [String] header value
  #
  # @api public
  def each_header(&block)
    raise NotImplementedError
  end

  # Ensure the response body is fully read so that the server is not blocked
  # waiting for us to read data from the socket. Also if the caller streamed
  # the response, but didn't read the data, we need a way to drain the socket
  # before adding the connection back to the connection pool, otherwise the
  # unread response data would "leak" into the next HTTP request/response.
  #
  # @api public
  def drain
    body
    true
  end
end
