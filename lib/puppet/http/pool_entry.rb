# frozen_string_literal: true

# An entry in the peristent HTTP pool that references the connection and
# an expiration time for the connection.
#
# @api private
class Puppet::HTTP::PoolEntry
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
