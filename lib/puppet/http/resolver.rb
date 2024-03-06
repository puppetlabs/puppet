# frozen_string_literal: true

# Resolver base class. Each resolver represents a different strategy for
# resolving a service name into a list of candidate servers and ports.
#
# @abstract Subclass and override {#resolve} to create a new resolver.
# @api public
class Puppet::HTTP::Resolver
  #
  # Create a new resolver.
  #
  # @param [Puppet::HTTP::Client] client
  def initialize(client)
    @client = client
  end

  # Return a working server/port for the resolver. This is the base
  # implementation and is meant to be a placeholder.
  #
  # @param [Puppet::HTTP::Session] session
  # @param [Symbol] name the service to resolve
  # @param [Puppet::SSL::SSLContext] ssl_context (nil) optional ssl context to
  #   use when creating a connection
  # @param [Proc] canceled_handler (nil) optional callback allowing a resolver
  #   to cancel resolution.
  #
  # @raise [NotImplementedError] this base class is not implemented
  #
  # @api public
  def resolve(session, name, ssl_context: nil, canceled_handler: nil)
    raise NotImplementedError
  end

  # Check a given connection to establish if it can be relied on for future use.
  #
  # @param [Puppet::HTTP::Session] session
  # @param [Puppet::HTTP::Service] service
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [Boolean] Returns true if a connection is successful, false otherwise
  #
  # @api public
  def check_connection?(session, service, ssl_context: nil)
    service.connect(ssl_context: ssl_context)
    true
  rescue Puppet::HTTP::ConnectionError => e
    Puppet.log_exception(e, "Connection to #{service.url} failed, trying next route: #{e.message}")
    false
  end
end
