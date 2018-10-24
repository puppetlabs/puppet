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
    Puppet.debug("Starting connection for #{site}")
    http.start
    begin
      yield http
    ensure
      Puppet.debug("Closing connection for #{site}")
      http.finish
    end
  end

  def close
    # do nothing
  end
end
