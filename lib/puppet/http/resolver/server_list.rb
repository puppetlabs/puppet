# frozen_string_literal: true

# Use the server_list setting to resolve a service. This resolver is only used
# if server_list is set either on the command line or in the configuration file.
#
# @api public
class Puppet::HTTP::Resolver::ServerList < Puppet::HTTP::Resolver
  # Create a server list resolver.
  #
  # @param [Puppet::HTTP::Client] client
  # @param [Array<String>] server_list_setting array of servers set via the
  #   configuration or the command line
  # @param [Integer] default_port if a port is not set for a server in
  #   server_list, use this port
  # @param [Array<Symbol>] services array of services that server_list can be
  #   used to resolve. If a service is not included in this array, this resolver
  #   will return nil.
  #
  def initialize(client, server_list_setting:, default_port:, services:)
    @client = client
    @server_list_setting = server_list_setting
    @default_port = default_port
    @services = services
  end

  # Walk the server_list to find a server and port that will connect successfully.
  #
  # @param [Puppet::HTTP::Session] session
  # @param [Symbol] name the name of the service being resolved
  # @param [Puppet::SSL::SSLContext] ssl_context
  # @param [Proc] canceled_handler optional callback allowing a resolver
  #   to cancel resolution.
  #
  # @return [nil] return nil if the service to be resolved does not support
  #   server_list
  # @return [Puppet::HTTP::Service] a validated service to use for future HTTP
  #   requests
  #
  # @raise [Puppet::Error] raise if none of the servers defined in server_list
  #   are available
  #
  # @api public
  def resolve(session, name, ssl_context: nil, canceled_handler: nil)
    # If we're configured to use an explicit service host, e.g. report_server
    # then don't use server_list to resolve the `:report` service.
    return nil unless @services.include?(name)

    # If we resolved the URL already, use its host & port for the service
    if @resolved_url
      return Puppet::HTTP::Service.create_service(@client, session, name, @resolved_url.host, @resolved_url.port)
    end

    # Return the first simple service status endpoint we can connect to
    @server_list_setting.value.each_with_index do |server, index|
      host = server[0]
      port = server[1] || @default_port

      service = Puppet::HTTP::Service.create_service(@client, session, :puppetserver, host, port)
      begin
        service.get_simple_status(ssl_context: ssl_context)
        @resolved_url = service.url
        return Puppet::HTTP::Service.create_service(@client, session, name, @resolved_url.host, @resolved_url.port)
      rescue Puppet::HTTP::ResponseError => detail
        if index < @server_list_setting.value.length - 1
          Puppet.warning(_("Puppet server %{host}:%{port} is unavailable: %{code} %{reason}") %
                              { host: service.url.host, port: service.url.port, code: detail.response.code, reason: detail.response.reason } +
                              ' ' + _("Trying with next server from server_list."))
        else
          Puppet.log_exception(detail, _("Puppet server %{host}:%{port} is unavailable: %{code} %{reason}") %
                               { host: service.url.host, port: service.url.port, code: detail.response.code, reason: detail.response.reason })
        end
      rescue Puppet::HTTP::HTTPError => detail
        if index < @server_list_setting.value.length - 1
          Puppet.warning(_("Unable to connect to server from server_list setting: %{detail}") % { detail: detail } +
                             ' ' + _("Trying with next server from server_list."))
        else
          Puppet.log_exception(detail, _("Unable to connect to server from server_list setting: %{detail}") % { detail: detail })
        end
      end
    end

    # don't fallback to other resolvers
    canceled_handler.call(true) if canceled_handler

    # not found
    nil
  end
end
