#
# @api private
#
# Represents the response returned from the server from an HTTP request
#
class Puppet::HTTP::Response
  # @api private
  # @return [Net::HTTP] the Net::HTTP response
  attr_reader :nethttp

  # @api private
  # @return [URI] the response uri
  attr_reader :url

  #
  # @api private
  #
  # Object to represent the response returned from an HTTP request
  #
  # @param [Net::HTTP] nethttp the request response
  # @param [URI] url
  #
  def initialize(nethttp, url)
    @nethttp = nethttp
    @url = url
  end

  #
  # @api private
  #
  # Extract the response code
  #
  # @return [Integer] Response code for the request
  #
  def code
    @nethttp.code.to_i
  end

  #
  # @api private
  #
  # Extract the response message
  #
  # @return [String] Response message for the request
  #
  def reason
    @nethttp.message
  end

  #
  # @api private
  #
  # Returns the entire response body. Can be used instead of
  #   Puppet::HTTP::Response.read_body, but both methods cannot be used for the
  #   same response.
  #
  # @return [String] Response body for the request
  #
  def body
    @nethttp.body
  end

  #
  # @api private
  #
  # Streams the response body to the caller in chunks. Can be used instead of
  #   Puppet::HTTP::Response.body, but both methods cannot be used for the same
  #   response.
  #
  # @yield [String] Streams the response body in chunks
  #
  # @raise [ArgumentError] raise if a block is not given
  #
  def read_body(&block)
    raise ArgumentError, "A block is required" unless block_given?

    @nethttp.read_body(&block)
  end

  #
  # @api private
  #
  # Check if the request received a response of success
  #
  # @return [Boolean] Returns true if the response indicates success
  #
  def success?
    @nethttp.is_a?(Net::HTTPSuccess)
  end

  # @api private
  def [](name)
    @nethttp[name]
  end

  # @api private
  def drain
    body
    true
  end
end
