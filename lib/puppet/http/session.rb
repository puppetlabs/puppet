class Puppet::HTTP::Session
  ServiceType = Struct.new(:service_class, :api, :server_setting, :port_setting)

  SERVICE_TYPES = {
    ca: ServiceType.new(Puppet::HTTP::Service::Ca, '/puppet-ca/v1', :ca_server, :ca_port),
  }.freeze

  def initialize(client, resolvers)
    @client = client
    @resolvers = resolvers
    @resolved_services = {}
  end

  def route_to(name, ssl_context: nil)
    raise ArgumentError, "Unknown service #{name}" if SERVICE_TYPES[name].nil?

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
    service_type = SERVICE_TYPES[name]
    raise ArgumentError, "Unknown service #{name}" unless service_type

    server ||= Puppet[service_type.server_setting]
    port   ||= Puppet[service_type.port_setting]
    url = URI::HTTPS.build(host: server,
                           port: port,
                           path: service_type.api
                          ).freeze
    service_type.service_class.new(@client, url)
  end
end
