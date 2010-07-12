class Puppet::Network::Client::Runner < Puppet::Network::Client::ProxyClient
  self.mkmethods

  def initialize(hash = {})
    hash[:Runner] = self.class.handler.new if hash.include?(:Runner)

    super(hash)
  end
end

