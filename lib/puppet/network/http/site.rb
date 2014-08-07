# Represents a site to which HTTP connections are made. It is a value
# object, and is suitable for use in a hash. If two sites are equal,
# then a persistent connection made to the first site, can be re-used
# for the second.
#
# @api private
#
class Puppet::Network::HTTP::Site
  attr_reader :scheme, :host, :port

  def initialize(scheme, host, port)
    @scheme = scheme
    @host = host
    @port = port.to_i
  end

  def addr
    "#{@scheme}://#{@host}:#{@port.to_s}"
  end
  alias to_s addr

  def ==(rhs)
    (@scheme == rhs.scheme) && (@host == rhs.host) && (@port == rhs.port)
  end

  alias eql? ==

  def hash
    [@scheme, @host, @port].hash
  end

  def use_ssl?
    @scheme == 'https'
  end

  def move_to(uri)
    self.class.new(uri.scheme, uri.host, uri.port)
  end
end
