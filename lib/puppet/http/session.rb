# frozen_string_literal: true

# The session is the mechanism by which services may be connected to and accessed.
#
# @api public
class Puppet::HTTP::Session
  # capabilities for a site
  CAP_LOCALES = 'locales'
  CAP_JSON = 'json'

  # puppet version where locales mount was added
  SUPPORTED_LOCALES_MOUNT_AGENT_VERSION = Gem::Version.new("5.3.4")

  # puppet version where JSON was enabled by default
  SUPPORTED_JSON_DEFAULT = Gem::Version.new("5.0.0")

  # Create a new HTTP session. The session is the mechanism by which services
  # may be connected to and accessed. Sessions should be created using
  # `Puppet::HTTP::Client#create_session`.
  #
  # @param [Puppet::HTTP::Client] client the container for this session
  # @param [Array<Puppet::HTTP::Resolver>] resolvers array of resolver strategies
  #   to implement.
  #
  # @api private
  def initialize(client, resolvers)
    @client = client
    @resolvers = resolvers
    @resolved_services = {}
    @server_versions = {}
  end

  # If an explicit server and port are specified on the command line or
  # configuration file, this method always returns a Service with that host and
  # port. Otherwise, we walk the list of resolvers in priority order:
  #     - DNS SRV
  #     - Server List
  #     - Puppet server/port settings
  # If a given resolver fails to connect, it tries the next available resolver
  # until a successful connection is found and returned. The successful service
  # is cached and returned if `route_to` is called again.
  #
  # @param [Symbol] name the service to resolve
  # @param [URI] url optional explicit url to use, if it is already known
  # @param [Puppet::SSL::SSLContext] ssl_context ssl context to be
  #   used for connections
  #
  # @return [Puppet::HTTP::Service] the resolved service
  #
  # @api public
  def route_to(name, url: nil, ssl_context: nil)
    raise ArgumentError, "Unknown service #{name}" unless Puppet::HTTP::Service.valid_name?(name)

    # short circuit if explicit URL host & port given
    if url && !url.host.nil? && !url.host.empty?
      service = Puppet::HTTP::Service.create_service(@client, self, name, url.host, url.port)
      service.connect(ssl_context: ssl_context)
      return service
    end

    cached = @resolved_services[name]
    return cached if cached

    canceled = false
    canceled_handler = ->(cancel) { canceled = cancel }

    @resolvers.each do |resolver|
      Puppet.debug("Resolving service '#{name}' using #{resolver.class}")
      service = resolver.resolve(self, name, ssl_context: ssl_context, canceled_handler: canceled_handler)
      if service
        @resolved_services[name] = service
        Puppet.debug("Resolved service '#{name}' to #{service.url}")
        return service
      elsif canceled
        break
      end
    end

    raise Puppet::HTTP::RouteError, "No more routes to #{name}"
  end

  # Collect per-site server versions. This will allow us to modify future
  # requests based on the version of puppetserver we are talking to.
  #
  # @param [Puppet::HTTP::Response] response the request response containing headers
  #
  # @api private
  def process_response(response)
    version = response[Puppet::HTTP::HEADER_PUPPET_VERSION]
    if version
      site = Puppet::HTTP::Site.from_uri(response.url)
      @server_versions[site] = version
    end
  end

  # Determine if a session supports a capability. Depending on the server version
  # we are talking to, we know certain features are available or not. These
  # specifications are defined here so we can modify our requests appropriately.
  #
  # @param [Symbol] name name of the service to check
  # @param [String] capability the capability, ie `locales` or `json`
  #
  # @return [Boolean]
  #
  # @api public
  def supports?(name, capability)
    raise ArgumentError, "Unknown service #{name}" unless Puppet::HTTP::Service.valid_name?(name)

    service = @resolved_services[name]
    return false unless service

    site = Puppet::HTTP::Site.from_uri(service.url)
    server_version = @server_versions[site]

    case capability
    when CAP_LOCALES
      !server_version.nil? && Gem::Version.new(server_version) >= SUPPORTED_LOCALES_MOUNT_AGENT_VERSION
    when CAP_JSON
      server_version.nil? || Gem::Version.new(server_version) >= SUPPORTED_JSON_DEFAULT
    else
      false
    end
  end
end
