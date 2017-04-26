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
      raise ArgumentError, _("Unknown arguments: %{args}") % { args: unknown.collect(&:inspect).join(', ') }
    end
  end

  def route_into(prefix)
    self.class.new(headers, params, method, path, routing_path.sub(prefix, ''), client_cert, body)
  end

  def formatter
    if header = headers['content-type']
      header.gsub!(/\s*;.*$/,'') # strip any charset
      format = Puppet::Network::FormatHandler.mime(header)

      return valid_network_format?(format) ? format : nil
    end

    raise Puppet::Network::HTTP::Error::HTTPBadRequestError.new(
      _("No Content-Type header was received, it isn't possible to unserialize the request"),
      Puppet::Network::HTTP::Issues::MISSING_HEADER_FIELD)
  end

  def format
    f = formatter
    f ? f.name.to_s : nil
  end

  def response_formatter_for(supported_formats, accepted_formats = headers['accept'])
    formatter = Puppet::Network::FormatHandler.most_suitable_format_for(
      accepted_formats.split(/\s*,\s*/),
      supported_formats)

    # we are only passed supported_formats that are suitable
    # and whose klass implements the required_methods
    return formatter if valid_network_format?(formatter)

    raise Puppet::Network::HTTP::Error::HTTPNotAcceptableError.new(
      _("No supported formats are acceptable (Accept: %{accepted_formats})") % { accepted_formats: accepted_formats },
      Puppet::Network::HTTP::Issues::UNSUPPORTED_FORMAT)
  end

  private

  def valid_network_format?(format)
    # YAML in network requests is not supported. See http://links.puppetlabs.com/deprecate_yaml_on_network
    format != nil && format.name != :yaml && format.name != :b64_zlib_yaml
  end
end
