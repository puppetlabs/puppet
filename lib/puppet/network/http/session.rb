# An HTTP session that references a persistent HTTP connection and
# an expiration time for the connection.
#
# @api private
#
class Puppet::Network::HTTP::Session
  attr_reader :connection

  def initialize(connection, expiration_time)
    @connection = connection
    @expiration_time = expiration_time
  end

  def expired?(now)
    @expiration_time <= now
  end
end
