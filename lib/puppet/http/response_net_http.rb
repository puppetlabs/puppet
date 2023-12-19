# frozen_string_literal: true

# Adapts Net::HTTPResponse to Puppet::HTTP::Response
#
# @api public
class Puppet::HTTP::ResponseNetHTTP < Puppet::HTTP::Response
  # Create a response associated with the URL.
  #
  # @param [URI] url
  # @param [Net::HTTPResponse] nethttp The response
  def initialize(url, nethttp)
    super(url, nethttp.code.to_i, nethttp.message)

    @nethttp = nethttp
  end

  # (see Puppet::HTTP::Response#body)
  def body
    @nethttp.body
  end

  # (see Puppet::HTTP::Response#read_body)
  def read_body(&block)
    raise ArgumentError, "A block is required" unless block_given?

    @nethttp.read_body(&block)
  end

  # (see Puppet::HTTP::Response#success?)
  def success?
    @nethttp.is_a?(Net::HTTPSuccess)
  end

  # (see Puppet::HTTP::Response#[])
  def [](name)
    @nethttp[name]
  end

  # (see Puppet::HTTP::Response#each_header)
  def each_header(&block)
    @nethttp.each_header(&block)
  end
end
