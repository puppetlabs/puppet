class Puppet::HTTP::Session
  def initialize(client, resolvers)
    @client = client
    @resolvers = resolvers
    @resolved_services = {}
    @resolution_exceptions = []
  end

  def route_to(name, ssl_context: nil)
    raise ArgumentError, "Unknown service #{name}" unless Puppet::HTTP::Service.valid_name?(name)

    cached = @resolved_services[name]
    return cached if cached

    @resolution_exceptions = []

    @resolvers.each do |resolver|
      Puppet.debug("Resolving service '#{name}' using #{resolver.class}")
      service = resolver.resolve(self, name, ssl_context: ssl_context)
      if service
        @resolved_services[name] = service
        Puppet.debug("Resolved service '#{name}' to #{service.url}")
        return service
      end
    end

    @resolution_exceptions.each { |e| Puppet.log_exception(e) }
    raise Puppet::HTTP::RouteError, "No more routes to #{name}"
  end

  def add_exception(exception)
    @resolution_exceptions << exception
  end
end
