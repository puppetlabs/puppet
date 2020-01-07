class Puppet::HTTP::Service
  attr_reader :url

  SERVICE_NAMES = [:ca, :report].freeze

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
end
