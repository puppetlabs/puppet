# An HTTP session that references a persistent HTTP connection and
# an expiration time for the connection.
#
# @api private
#
class Puppet::Network::HTTP::Session
  attr_reader :connection, :verifier

  def initialize(connection, verifier, expiration_time)
    @connection = connection
    @verifier = verifier
    @expiration_time = expiration_time
  end

  def expired?(now)
    @expiration_time <= now
  end
end
