require 'puppet/file_serving/metadata'

class Puppet::HTTP::Service::FileServer < Puppet::HTTP::Service
  API = '/puppet/v3'.freeze
  PATH_REGEX = /^\//

  def initialize(client, server, port)
    url = build_url(API, server || Puppet[:server], port || Puppet[:masterport])
    super(client, url)
  end

  def get_file_metadata(path:, environment:, links: :manage, checksum_type: Puppet[:digest_algorithm], source_permissions: :ignore, ssl_context: nil)
    validate_path(path)

    headers = add_puppet_headers({ 'Accept' => get_mime_types(Puppet::FileServing::Metadata).join(', ') })

    response = @client.get(
      with_base_url("/file_metadata#{path}"),
      headers: headers,
      params: {
        links: links,
        checksum_type: checksum_type,
        source_permissions: source_permissions,
        environment: environment
      },
      ssl_context: ssl_context
    )

    return deserialize(response, Puppet::FileServing::Metadata) if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end

  def get_file_metadatas(path: nil, environment:, recurse: :false, recurselimit: nil, ignore: nil, links: :manage, checksum_type: Puppet[:digest_algorithm], source_permissions: :ignore, ssl_context: nil)
    validate_path(path)

    headers = add_puppet_headers({ 'Accept' => get_mime_types(Puppet::FileServing::Metadata).join(', ') })

    response = @client.get(
      with_base_url("/file_metadatas#{path}"),
      headers: headers,
      params: {
        recurse: recurse,
        recurselimit: recurselimit,
        ignore: ignore,
        links: links,
        checksum_type: checksum_type,
        source_permissions: source_permissions,
        environment: environment,
      },
      ssl_context: ssl_context
    )

    return deserialize_multiple(response, Puppet::FileServing::Metadata) if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end

  def get_file_content(path:, environment:, ssl_context: nil, &block)
    validate_path(path)

    headers = add_puppet_headers({'Accept' => 'application/octet-stream' })
    response = @client.get(
      with_base_url("/file_content#{path}"),
      headers: headers,
      params: {
        environment: environment
      },
      ssl_context: ssl_context
    ) do |res|
      if res.success?
        res.read_body(&block)
      end
    end

    return nil if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end
  private

  def validate_path(path)
    raise ArgumentError, "Path must start with a slash" unless path =~ PATH_REGEX
  end
end
