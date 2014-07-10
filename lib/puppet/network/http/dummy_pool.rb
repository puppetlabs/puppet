class Puppet::Network::HTTP::DummyPool
  def take_connection(site, factory)
    factory.create_connection(site)
  end

  def close
    # do nothing
  end
end
