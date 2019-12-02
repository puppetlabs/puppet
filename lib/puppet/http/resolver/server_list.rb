class Puppet::HTTP::Resolver::ServerList < Puppet::HTTP::Resolver
  def initialize(client, server_list:, default_port:)
    @client = client
    @server_list = server_list
    @default_port = default_port
  end

  def resolve(session, name, ssl_context: nil)
    @server_list.each do |server|
      host = server[0]
      port = server[1] || @default_port
      uri = URI("https://#{host}:#{port}/status/v1/simple/master")
      if get_success?(uri, session, ssl_context: ssl_context)
        return Puppet::HTTP::Service.create_service(@client, name, host, port)
      end
    end

    raise Puppet::Error, _("Could not select a functional puppet master from server_list: '%{server_list}'") % { server_list: Puppet.settings.value(:server_list, Puppet[:environment].to_sym, true) }
  end

  def get_success?(uri, session, ssl_context: nil)
    response = @client.get(uri, ssl_context: ssl_context)
    return true if response.success?

    Puppet.debug(_("Puppet server %{host}:%{port} is unavailable: %{code} %{reason}") %
                 { host: host, port: port, code: response.code, reason: response.message })
    return false
  rescue => detail
    session.add_exception(detail)
    #TRANSLATORS 'server_list' is the name of a setting and should not be translated
    Puppet.debug _("Unable to connect to server from server_list setting: %{detail}") % {detail: detail}
    return false
  end
end
