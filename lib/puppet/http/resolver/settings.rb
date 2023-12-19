# frozen_string_literal: true

# Resolve a service using settings. This is the default resolver if none of the
# other resolvers find a functional connection.
#
# @api public
class Puppet::HTTP::Resolver::Settings < Puppet::HTTP::Resolver
  # Resolve a service using the default server and port settings for this service.
  #
  # @param [Puppet::HTTP::Session] session
  # @param [Symbol] name the name of the service to be resolved
  # @param [Puppet::SSL::SSLContext] ssl_context
  # @param [Proc] canceled_handler optional callback allowing a resolver
  #   to cancel resolution.
  #
  # @return [Puppet::HTTP::Service] if the service successfully connects,
  #   return it. Otherwise, return nil.
  #
  # @api public
  def resolve(session, name, ssl_context: nil, canceled_handler: nil)
    service = Puppet::HTTP::Service.create_service(@client, session, name)
    check_connection?(session, service, ssl_context: ssl_context) ? service : nil
  end
end
