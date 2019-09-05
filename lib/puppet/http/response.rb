class Puppet::HTTP::Response
  def initialize(nethttp)
    @nethttp = nethttp
  end

  def code
    @nethttp.code.to_i
  end

  def reason
    @nethttp.message
  end

  def body
    @nethttp.body
  end

  def read_body(&block)
    @nethttp.read_body(&block)
  end

  def success?
    @nethttp.is_a?(Net::HTTPSuccess)
  end

  def [](name)
    @nethttp[name]
  end

  def drain
    body
    true
  end
end
