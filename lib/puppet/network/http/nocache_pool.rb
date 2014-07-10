class Puppet::Network::HTTP::NoCachePool
  def with_connection(site, factory, &block)
    connection = factory.create_connection(site)
    yield connection
  end

  def close
    # do nothing
  end
end
