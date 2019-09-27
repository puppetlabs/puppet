class Puppet::HTTP::Resolver::SRV < Puppet::HTTP::Resolver
  def initialize(domain: srv_domain, dns: Resolv::DNS.new)
    @srv_domain = domain
    @delegate = Puppet::Network::Resolver.new(dns)
  end

  def resolve(session, name, &block)
    # This assumes the route name is the same as the DNS SRV name
    @delegate.each_srv_record(@srv_domain, name) do |server, port|
      yield session.create_service(name, server, port)
    end
  end
end
