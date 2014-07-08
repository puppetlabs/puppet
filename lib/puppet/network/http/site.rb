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
end
