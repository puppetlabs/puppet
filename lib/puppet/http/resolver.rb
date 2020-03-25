#
# @api private
#
# Resolver base class. Each resolver represents a different strategy for
# resolving a service name into a list of candidate servers and ports.
#
class Puppet::HTTP::Resolver
  #
  # @api private
  #
  # Create a new resolver
  #
  # @param [Puppet::HTTP::Client] client
  #
  def initialize(client)
    @client = client
  end

  #
  # @api private
  #
  # Return a working server/port for the resolver. This is the base
  # implementation and is meant to be a placeholder.
  #
  # @param [Puppet::HTTP::Session] session
  # @param [Symbol] name the service to resolve
  # @param [Puppet::SSL::SSLContext] ssl_context (nil) optional ssl context to
  #   use when creating a connection
  #
  # @raise [NotImplementedError] this base class is not implemented
  #
  def resolve(session, name, ssl_context: nil)
    raise NotImplementedError
  end

  #
  # @api private
  #
  # Check a given connection to establish if it can be relied on for future use
  #
  # @param [Puppet::HTTP::Session] session
  # @param [Puppet::HTTP::Service] service
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [Boolean] Returns true if a connection is successful, false otherwise
  #
  def check_connection?(session, service, ssl_context: nil)
    service.connect(ssl_context: ssl_context)
    return true
  rescue Puppet::HTTP::ConnectionError => e
    session.add_exception(e)
    Puppet.debug("Connection to #{service.url} failed, trying next route: #{e.message}")
    return false
  end
end
