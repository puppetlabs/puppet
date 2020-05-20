# A pool that does not cache HTTP connections.
#
# @api private
class Puppet::Network::HTTP::NoCachePool < Puppet::Network::HTTP::BasePool
  def initialize(factory = Puppet::Network::HTTP::Factory.new)
    Puppet.deprecation_warning(_('Puppet::Network::HTTP::NoCachePool is deprecated.'))
    @factory = factory
  end

  # Yields a <tt>Net::HTTP</tt> connection.
  #
  # @yieldparam http [Net::HTTP] An HTTP connection
  def with_connection(site, verifier, &block)
    http = @factory.create_connection(site)
    start(site, verifier, http)
    begin
      yield http
    ensure
      return unless http.started?
      Puppet.debug("Closing connection for #{site}")
      http.finish
    end
  end

  def close
    # do nothing
  end
end
