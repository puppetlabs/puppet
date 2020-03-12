#
# @api private
#
# Use the server_list setting to resolve a service. This resolver is only used
# if server_list is set either on the command line or in the configuration file.
#
class Puppet::HTTP::Resolver::ServerList < Puppet::HTTP::Resolver
  #
  # @api private
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
  def initialize(client, server_list_setting:, default_port:, services: )
    @client = client
    @server_list_setting = server_list_setting
    @default_port = default_port
    @services = services
    @resolved_url = nil
  end

  #
  # @api private
  #
  # Walk the server_list to find a server and port that will connect successfully.
  #
  # @param [Puppet::HTTP::Session] session <description>
  # @param [Symbol] name the name of the service being resolved
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [nil] return nil if the service to be resolved does not support
  #   server_list
  # @return [Puppet::HTTP::Service] a validated service to use for future HTTP
  #   requests
  #
  # @raise [Puppet::Error] raise if none of the servers defined in server_list
  #   are available
  #
  def resolve(session, name, ssl_context: nil)
    # If we're configured to use an explicit service host, e.g. report_server
    # then don't use server_list to resolve the `:report` service.
    return nil unless @services.include?(name)

    # If we resolved the URL already, use its host & port for the service
    if @resolved_url
      return Puppet::HTTP::Service.create_service(@client, session, name, @resolved_url.host, @resolved_url.port)
    end

    # Return the first simple service status endpoint we can connect to
    @server_list_setting.value.each do |server|
      host = server[0]
      port = server[1] || @default_port
      uri = URI("https://#{host}:#{port}/status/v1/simple/master")
      if get_success?(uri, session, ssl_context: ssl_context)
        @resolved_url = uri
        return Puppet::HTTP::Service.create_service(@client, session, name, host, port)
      end
    end

    raise Puppet::Error, _("Could not select a functional puppet master from server_list: '%{server_list}'") % { server_list: @server_list_setting.print(@server_list_setting.value) }
  end

  #
  # @api private
  #
  # Check if a server and port is available
  #
  # @param [URI] uri A URI created from the server and port to test
  # @param [Puppet::HTTP::Session] session
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [Boolean] true if a successful response is returned by the server,
  #   false otherwise
  #
  def get_success?(uri, session, ssl_context: nil)
    response = @client.get(uri, options: {ssl_context: ssl_context})
    return true if response.success?

    Puppet.debug(_("Puppet server %{host}:%{port} is unavailable: %{code} %{reason}") %
                 { host: uri.host, port: uri.port, code: response.code, reason: response.reason })
    return false
  rescue => detail
    session.add_exception(detail)
    #TRANSLATORS 'server_list' is the name of a setting and should not be translated
    Puppet.debug _("Unable to connect to server from server_list setting: %{detail}") % {detail: detail}
    return false
  end
end
