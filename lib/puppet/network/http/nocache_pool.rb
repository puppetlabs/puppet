class Puppet::Network::HTTP::NoCachePool
  def initialize(factory = Puppet::Network::HTTP::Factory.new)
    @factory = factory
  end

  def with_connection(site, verify, &block)
    http = @factory.create_connection(site)
    verify.setup_connection(http)
    yield http
  end

  def close
    # do nothing
  end
end
