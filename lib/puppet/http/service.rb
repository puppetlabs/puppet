class Puppet::HTTP::Service
  attr_reader :url

  SERVICE_NAMES = [:ca, :report].freeze
  EXCLUDED_FORMATS = [:yaml, :b64_zlib_yaml, :dot].freeze

  def self.create_service(client, name, server = nil, port = nil)
    case name
    when :ca
      Puppet::HTTP::Service::Ca.new(client, server, port)
    when :report
      Puppet::HTTP::Service::Report.new(client, server, port)
    else
      raise ArgumentError, "Unknown service #{name}"
    end
  end

  def self.valid_name?(name)
    SERVICE_NAMES.include?(name)
  end

  def initialize(client, url)
    @client = client
    @url = url
  end

  def with_base_url(path)
    u = @url.dup
    u.path += path
    u
  end

  def connect(ssl_context: nil)
    @client.connect(@url, ssl_context: ssl_context)
  end

  protected

  def add_puppet_headers(headers)
    modified_headers = headers.dup
    modified_headers['X-Puppet-Profiling'] = 'true' if Puppet[:profile]
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
end
