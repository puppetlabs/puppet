class Puppet::HTTP::Resolver
  def resolve(session, name, &block)
    raise NotImplementedError
  end
end
