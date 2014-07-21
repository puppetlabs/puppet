class Puppet::Network::HTTP::NoCachePool
  attr_reader :factory

  def initialize
    @factory = Puppet::Network::HTTP::Factory.new
  end

  def with_connection(conn, &block)
    http = @factory.create_connection(conn.site)
    conn.initialize_ssl(http)
    yield http
  end

  def close
    # do nothing
  end
end
