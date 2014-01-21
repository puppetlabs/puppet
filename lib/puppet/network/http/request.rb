Puppet::Network::HTTP::Request = Struct.new(:headers, :params, :method, :path, :routing_path, :client_cert, :body) do
  def self.from_hash(hash)
    symbol_members = members.collect(&:intern)
    unknown = hash.keys - symbol_members
    if unknown.empty?
      new(hash[:headers] || {},
          hash[:params] || {},
          hash[:method] || "GET",
          hash[:path],
          hash[:routing_path] || hash[:path],
          hash[:client_cert],
          hash[:body])
    else
      raise ArgumentError, "Unknown arguments: #{unknown.collect(&:inspect).join(', ')}"
    end
  end

  def route_into(prefix)
    self.class.new(headers, params, method, path, routing_path.sub(prefix, ''), client_cert, body)
  end

  def format
    if header = headers['content-type']
      header.gsub!(/\s*;.*$/,'') # strip any charset
      format = Puppet::Network::FormatHandler.mime(header)
      if format.nil?
        raise "Client sent a mime-type (#{header}) that doesn't correspond to a format we support"
      else
        report_if_deprecated(format)
        return format.name.to_s if format.suitable?
      end
    end

    raise "No Content-Type header was received, it isn't possible to unserialize the request"
  end

  def response_formatter_for(supported_formats, accepted_formats = headers['accept'])
    formatter = Puppet::Network::FormatHandler.most_suitable_format_for(
      accepted_formats.split(/\s*,\s*/),
      supported_formats)

      if formatter.nil?
        raise Puppet::Network::HTTP::Error::HTTPNotAcceptableError.new("No supported formats are acceptable (Accept: #{accepted_formats})", Puppet::Network::HTTP::Issues::UNSUPPORTED_FORMAT)
      end

      report_if_deprecated(formatter)

      formatter
  end

  def report_if_deprecated(format)
    if format.name == :yaml || format.name == :b64_zlib_yaml
      Puppet.deprecation_warning("YAML in network requests is deprecated and will be removed in a future version. See http://links.puppetlabs.com/deprecate_yaml_on_network")
    end
  end
end
