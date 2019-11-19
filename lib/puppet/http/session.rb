class Puppet::HTTP::Session
  def initialize(client, resolvers)
    @client = client
    @resolvers = resolvers
    @resolved_services = {}
  end

  def route_to(name, ssl_context: nil)
    raise ArgumentError, "Unknown service #{name}" unless Puppet::HTTP::Service.valid_name?(name)

    cached = @resolved_services[name]
    return cached if cached

    errors = []

    @resolvers.each do |resolver|
      Puppet.debug("Resolving service '#{name}' using #{resolver.class}")
      resolver.resolve(self, name) do |service|
        begin
          service.connect(ssl_context: ssl_context)
          @resolved_services[name] = service
          Puppet.debug("Resolved service '#{name}' to #{service.url}")
          return service
        rescue Puppet::HTTP::ConnectionError => e
          errors << e
          Puppet.debug("Connection to #{service.url} failed, trying next route: #{e.message}")
        end
      end
    end

    errors.each { |e| Puppet.log_exception(e) }

    raise Puppet::HTTP::RouteError, "No more routes to #{name}"
  end

  def create_service(name, server = nil, port = nil)
    Puppet::HTTP::Service.create_service(@client, name, server, port)
  end
end
