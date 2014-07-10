class Puppet::Network::HTTP::DummyPool
  def with_connection(site, factory, &block)
    connection = factory.create_connection(site)
    yield connection
  end

  def close
    # do nothing
  end
end
