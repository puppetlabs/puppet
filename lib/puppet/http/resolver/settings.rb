class Puppet::HTTP::Resolver::Settings < Puppet::HTTP::Resolver
  def resolve(session, name, ssl_context: nil)
    service = Puppet::HTTP::Service.create_service(@client, session, name)
    check_connection?(session, service, ssl_context: ssl_context) ? service : nil
  end
end
