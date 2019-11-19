class Puppet::HTTP::Resolver::SRV < Puppet::HTTP::Resolver
  def initialize(domain: srv_domain, dns: Resolv::DNS.new)
    @srv_domain = domain
    @delegate = Puppet::Network::Resolver.new(dns)
  end

  def resolve(session, name, &block)
    # Here we pass our HTTP service name as the DNS SRV service name
    # This is fine for :ca, but note that :puppet and :file are handled
    # specially in `each_srv_record`.
    @delegate.each_srv_record(@srv_domain, name) do |server, port|
      yield session.create_service(name, server, port)
    end
  end
end
