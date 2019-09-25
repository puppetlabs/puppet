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

  def success?
    @nethttp.is_a?(Net::HTTPSuccess)
  end
end
