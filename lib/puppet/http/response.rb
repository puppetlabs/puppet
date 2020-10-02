# Represents the response returned from the server from an HTTP request.
#
# @api public
class Puppet::HTTP::Response
  # @api private
  # @return [Net::HTTP] the Net::HTTP response
  attr_reader :nethttp

  # @return [URI] the response uri
  attr_reader :url

  # Object to represent the response returned from an HTTP request.
  #
  # @param [Net::HTTP] nethttp the request response
  # @param [URI] url
  def initialize(nethttp, url)
    @nethttp = nethttp
    @url = url
  end

  # Extract the response code.
  #
  # @return [Integer] Response code for the request
  #
  # @api public
  def code
    @nethttp.code.to_i
  end

  # Extract the response message.
  #
  # @return [String] Response message for the request
  #
  # @api public
  def reason
    @nethttp.message
  end

  # Returns the entire response body. Can be used instead of
  #   `Puppet::HTTP::Response.read_body`, but both methods cannot be used for the
  #   same response.
  #
  # @return [String] Response body for the request
  #
  # @api public
  def body
    @nethttp.body
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
    raise ArgumentError, "A block is required" unless block_given?

    @nethttp.read_body(&block)
  end

  # Check if the request received a response of success (HTTP 2xx).
  #
  # @return [Boolean] Returns true if the response indicates success
  #
  # @api public
  def success?
    @nethttp.is_a?(Net::HTTPSuccess)
  end

  # Get a header case-insensitively.
  #
  # @param [String] name The header name
  # @return [String] The header value
  #
  # @api public
  def [](name)
    @nethttp[name]
  end

  # Yield each header name and value. Returns an enumerator if no block is given.
  #
  # @yieldparam [String] header name
  # @yieldparam [String] header value
  #
  # @api public
  def each_header(&block)
    @nethttp.each_header(&block)
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
