class Puppet::HTTP::Resolver
  def initialize(client)
    @client = client
  end

  def resolve(session, name, ssl_context: nil)
    raise NotImplementedError
  end

  def check_connection?(session, service, ssl_context: nil)
    service.connect(ssl_context: ssl_context)
    return true
  rescue Puppet::HTTP::ConnectionError => e
    session.add_exception(e)
    Puppet.debug("Connection to #{service.url} failed, trying next route: #{e.message}")
    return false
  end
end
