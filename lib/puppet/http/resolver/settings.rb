class Puppet::HTTP::Resolver::Settings < Puppet::HTTP::Resolver
  def resolve(session, name, &block)
    yield session.create_service(name)
  end
end
