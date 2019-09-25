class Puppet::HTTP::Resolver::SRV < Puppet::HTTP::Resolver
  def initialize(srv_domain)
    @srv_domain = srv_domain
    @dns = Puppet::Network::Resolver.new
  end

  def resolve(session, name, &block)
    # This assumes the route name is the same as the DNS SRV name
    @dns.each_srv_record(@srv_domain, name) do |server, port|
      yield session.create_service(name, server, port)
    end
  end
end
