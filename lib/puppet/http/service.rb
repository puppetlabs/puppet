# frozen_string_literal: true

# Represents an abstract Puppet web service.
#
# @abstract Subclass and implement methods for the service's REST APIs.
# @api public
class Puppet::HTTP::Service
  # @return [URI] the url associated with this service
  attr_reader :url

  # @return [Array<Symbol>] available services
  SERVICE_NAMES = [:ca, :fileserver, :puppet, :puppetserver, :report].freeze

  # @return [Array<Symbol>] format types that are unsupported
  EXCLUDED_FORMATS = [:yaml, :b64_zlib_yaml, :dot].freeze

  # Create a new web service, which contains the URL used to connect to the
  # service. The four services implemented are `:ca`, `:fileserver`, `:puppet`,
  # and `:report`.
  #
  # The `:ca` and `:report` services handle certs and reports, respectively. The
  # `:fileserver` service handles puppet file metadata and content requests. And
  # the default service, `:puppet`, handles nodes, facts, and catalogs.
  #
  # @param [Puppet::HTTP::Client] client the owner of the session
  # @param [Puppet::HTTP::Session] session the owner of the service
  # @param [Symbol] name the type of service to create
  # @param [<Type>] server optional, the server to connect to
  # @param [<Type>] port optional, the port to connect to
  #
  # @return [Puppet::HTTP::Service] an instance of the service type requested
  #
  # @api private
  def self.create_service(client, session, name, server = nil, port = nil)
    case name
    when :ca
      Puppet::HTTP::Service::Ca.new(client, session, server, port)
    when :fileserver
      Puppet::HTTP::Service::FileServer.new(client, session, server, port)
    when :puppet
      ::Puppet::HTTP::Service::Compiler.new(client, session, server, port)
    when :puppetserver
      ::Puppet::HTTP::Service::Puppetserver.new(client, session, server, port)
    when :report
      Puppet::HTTP::Service::Report.new(client, session, server, port)
    else
      raise ArgumentError, "Unknown service #{name}"
    end
  end

  # Check if the service named is included in the list of available services.
  #
  # @param [Symbol] name
  #
  # @return [Boolean]
  #
  # @api private
  def self.valid_name?(name)
    SERVICE_NAMES.include?(name)
  end

  # Create a new service. Services should be created by calling `Puppet::HTTP::Session#route_to`.
  #
  # @param [Puppet::HTTP::Client] client
  # @param [Puppet::HTTP::Session] session
  # @param [URI] url The url to connect to
  #
  # @api private
  def initialize(client, session, url)
    @client = client
    @session = session
    @url = url
  end

  # Return the url with the given path encoded and appended
  #
  # @param [String] path the string to append to the base url
  #
  # @return [URI] the URI object containing the encoded path
  #
  # @api public
  def with_base_url(path)
    u = @url.dup
    u.path += Puppet::Util.uri_encode(path)
    u
  end

  # Open a connection using the given ssl context.
  #
  # @param [Puppet::SSL::SSLContext] ssl_context An optional ssl context to connect with
  # @return [void]
  #
  # @api public
  def connect(ssl_context: nil)
    @client.connect(@url, options: { ssl_context: ssl_context })
  end

  protected

  def add_puppet_headers(headers)
    modified_headers = headers.dup

    # Add 'X-Puppet-Profiling' to enable performance profiling if turned on
    modified_headers['X-Puppet-Profiling'] = 'true' if Puppet[:profile]

    # Add additional user-defined headers if they are defined
    Puppet[:http_extra_headers].each do |name, value|
      if modified_headers.keys.find { |key| key.casecmp(name) == 0 }
        Puppet.warning(_('Ignoring extra header "%{name}" as it was previously set.') % { name: name })
      elsif value.nil? || value.empty?
        Puppet.warning(_('Ignoring extra header "%{name}" as it has no value.') % { name: name })
      else
        modified_headers[name] = value
      end
    end
    modified_headers
  end

  def build_url(api, server, port)
    URI::HTTPS.build(host: server,
                     port: port,
                     path: api).freeze
  end

  def get_mime_types(model)
    network_formats = model.supported_formats - EXCLUDED_FORMATS
    network_formats.map { |f| model.get_format(f).mime }
  end

  def formatter_for_response(response)
    header = response['Content-Type']
    raise Puppet::HTTP::ProtocolError, _("No content type in http response; cannot parse") unless header

    header.gsub!(/\s*;.*$/, '') # strip any charset

    formatter = Puppet::Network::FormatHandler.mime(header)
    raise Puppet::HTTP::ProtocolError, "Content-Type is unsupported" if EXCLUDED_FORMATS.include?(formatter.name)

    formatter
  end

  def serialize(formatter, object)
    begin
      formatter.render(object)
    rescue => err
      raise Puppet::HTTP::SerializationError.new("Failed to serialize #{object.class} to #{formatter.name}: #{err.message}", err)
    end
  end

  def serialize_multiple(formatter, object)
    begin
      formatter.render_multiple(object)
    rescue => err
      raise Puppet::HTTP::SerializationError.new("Failed to serialize multiple #{object.class} to #{formatter.name}: #{err.message}", err)
    end
  end

  def deserialize(response, model)
    formatter = formatter_for_response(response)
    begin
      formatter.intern(model, response.body.to_s)
    rescue => err
      raise Puppet::HTTP::SerializationError.new("Failed to deserialize #{model} from #{formatter.name}: #{err.message}", err)
    end
  end

  def deserialize_multiple(response, model)
    formatter = formatter_for_response(response)
    begin
      formatter.intern_multiple(model, response.body.to_s)
    rescue => err
      raise Puppet::HTTP::SerializationError.new("Failed to deserialize multiple #{model} from #{formatter.name}: #{err.message}", err)
    end
  end

  def process_response(response)
    @session.process_response(response)

    raise Puppet::HTTP::ResponseError, response unless response.success?
  end
end
