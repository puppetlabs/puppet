require 'semantic_puppet'

class Puppet::HTTP::Session
  def initialize(client, resolvers)
    @client = client
    @resolvers = resolvers
    @resolved_services = {}
    @resolution_exceptions = []
    @server_versions = {}
  end

  def route_to(name, url: nil, ssl_context: nil)
    raise ArgumentError, "Unknown service #{name}" unless Puppet::HTTP::Service.valid_name?(name)

    # short circuit if explicit URL host & port given
    if url && url.host != nil && !url.host.empty?
      service = Puppet::HTTP::Service.create_service(@client, self, name, url.host, url.port)
      service.connect(ssl_context: ssl_context)
      return service
    end

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

  def process_response(response)
    version = response[Puppet::HTTP::HEADER_PUPPET_VERSION]
    if version
      site = Puppet::Network::HTTP::Site.from_uri(response.url)
      @server_versions[site] = SemanticPuppet::Version.parse(version)
    end
  end

  def server_version(url)
    site = Puppet::Network::HTTP::Site.from_uri(url)
    @server_versions[site] || SemanticPuppet::Version.parse("4.0.0")
  end
end
