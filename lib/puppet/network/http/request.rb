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

      return format if valid_network_format?(format)

      #TRANSLATORS "mime-type" is a keyword and should not be translated
      raise Puppet::Network::HTTP::Error::HTTPUnsupportedMediaTypeError.new(
              _("Client sent a mime-type (%{header}) that doesn't correspond to a format we support") % { header: headers['content-type'] },
              Puppet::Network::HTTP::Issues::UNSUPPORTED_MEDIA_TYPE)
    end

    raise Puppet::Network::HTTP::Error::HTTPBadRequestError.new(
            _("No Content-Type header was received, it isn't possible to unserialize the request"),
            Puppet::Network::HTTP::Issues::MISSING_HEADER_FIELD)
  end

  def response_formatters_for(supported_formats, default_accepted_formats = nil)
    accepted_formats = headers['accept'] || default_accepted_formats

    if accepted_formats.nil?
      raise Puppet::Network::HTTP::Error::HTTPBadRequestError.new(_("Missing required Accept header"), Puppet::Network::HTTP::Issues::MISSING_HEADER_FIELD)
    end

    formats = Puppet::Network::FormatHandler.most_suitable_formats_for(
      accepted_formats.split(/\s*,\s*/),
      supported_formats)

    formats.find_all do |format|
      # we are only passed supported_formats that are suitable
      # and whose klass implements the required_methods
      valid_network_format?(format)
    end

    return formats unless formats.empty?

    raise Puppet::Network::HTTP::Error::HTTPNotAcceptableError.new(
      _("No supported formats are acceptable (Accept: %{accepted_formats})") % { accepted_formats: accepted_formats },
      Puppet::Network::HTTP::Issues::UNSUPPORTED_FORMAT)
  end

  private

  def valid_network_format?(format)
    # YAML in network requests is not supported. See http://links.puppet.com/deprecate_yaml_on_network
    format != nil && format.name != :yaml && format.name != :b64_zlib_yaml
  end
end
