require 'puppet/network/http/connection'

module Puppet::Network; end

# This class is basically a placeholder for managing a pool of HTTP connections; at present
#  it does not actually attempt to pool them, but provides an abstraction that is used in
#  other places in the code should we decide to implement pooling at some point in the
#  future.
module Puppet::Network::HttpPool

  # Retrieve a cached http instance if caching is enabled, else return
  # a new one.
  def self.http_instance(host, port, use_ssl = true)
    Puppet::Network::HTTP::Connection.new(host, port, use_ssl)
  end

end
