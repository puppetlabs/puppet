# A pool that does not cache HTTP connections.
#
# @api private
class Puppet::Network::HTTP::NoCachePool
  def initialize(factory = Puppet::Network::HTTP::Factory.new)
    @factory = factory
  end

  # Yields a <tt>Net::HTTP</tt> connection.
  #
  # @yieldparam http [Net::HTTP] An HTTP connection
  def with_connection(site, verify, &block)
    http = @factory.create_connection(site)
    verify.setup_connection(http)
    yield http
  end

  def close
    # do nothing
  end
end
