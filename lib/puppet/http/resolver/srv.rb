class Puppet::HTTP::Resolver::SRV < Puppet::HTTP::Resolver
  def initialize(client, domain:, dns: Resolv::DNS.new)
    @client = client
    @srv_domain = domain
    @delegate = Puppet::Network::Resolver.new(dns)
  end

  def resolve(session, name, ssl_context: nil)
    # Here we pass our HTTP service name as the DNS SRV service name
    # This is fine for :ca, but note that :puppet and :file are handled
    # specially in `each_srv_record`.
    @delegate.each_srv_record(@srv_domain, name) do |server, port|
      service = Puppet::HTTP::Service.create_service(@client, session, name, server, port)
      return service if check_connection?(session, service, ssl_context: ssl_context)
    end

    return nil
  end
end
