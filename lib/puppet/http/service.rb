class Puppet::HTTP::Service
  attr_reader :url

  SERVICE_NAMES = [:ca, :fileserver, :puppet, :report].freeze
  EXCLUDED_FORMATS = [:yaml, :b64_zlib_yaml, :dot].freeze

  def self.create_service(client, session, name, server = nil, port = nil)
    case name
    when :ca
      Puppet::HTTP::Service::Ca.new(client, session, server, port)
    when :fileserver
      Puppet::HTTP::Service::FileServer.new(client, session, server, port)
    when :puppet
      ::Puppet::HTTP::Service::Compiler.new(client, session, server, port)
    when :report
      Puppet::HTTP::Service::Report.new(client, session, server, port)
    else
      raise ArgumentError, "Unknown service #{name}"
    end
  end

  def self.valid_name?(name)
    SERVICE_NAMES.include?(name)
  end

  def initialize(client, session, url)
    @client = client
    @session = session
    @url = url
  end

  def with_base_url(path)
    u = @url.dup
    u.path += Puppet::Util.uri_encode(path)
    u
  end

  def connect(ssl_context: nil)
    @client.connect(@url, ssl_context: ssl_context)
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
      else
        if value.nil? || value.empty?
          Puppet.warning(_('Ignoring extra header "%{name}" as it has no value.') % { name: name })
        else
          modified_headers[name] = value
        end
      end
    end
    modified_headers
  end

  def build_url(api, server, port)
    URI::HTTPS.build(host: server,
                     port: port,
                     path: api
                    ).freeze
  end

  def get_mime_types(model)
    unless @mime_types
      network_formats = model.supported_formats - EXCLUDED_FORMATS
      @mime_types = network_formats.map { |f| model.get_format(f).mime }
    end
    @mime_types
  end

  def formatter_for_response(response)
    header = response['Content-Type']
    raise Puppet::HTTP::ProtocolError.new(_("No content type in http response; cannot parse")) unless header

    header.gsub!(/\s*;.*$/,'') # strip any charset

    formatter = Puppet::Network::FormatHandler.mime(header)
    raise Puppet::HTTP::ProtocolError.new("Content-Type is unsupported") if EXCLUDED_FORMATS.include?(formatter.name)

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
end
