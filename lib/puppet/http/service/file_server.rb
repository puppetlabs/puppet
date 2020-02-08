require 'puppet/file_serving/metadata'

class Puppet::HTTP::Service::FileServer < Puppet::HTTP::Service
  API = '/puppet/v3'.freeze
  PATH_REGEX = /^\//

  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:server], port || Puppet[:masterport])
    super(client, session, url)
  end

  def get_file_metadata(path:, environment:, links: :manage, checksum_type: Puppet[:digest_algorithm], source_permissions: :ignore, ssl_context: nil)
    validate_path(path)

    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::FileServing::Metadata).join(', '))

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

    handle_response_errors(response)

    return deserialize(response, Puppet::FileServing::Metadata)
  end

  def get_file_metadatas(path: nil, environment:, recurse: :false, recurselimit: nil, ignore: nil, links: :manage, checksum_type: Puppet[:digest_algorithm], source_permissions: :ignore, ssl_context: nil)
    validate_path(path)

    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::FileServing::Metadata).join(', '))

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

    handle_response_errors(response)

    return deserialize_multiple(response, Puppet::FileServing::Metadata)
  end

  def get_file_content(path:, environment:, ssl_context: nil, &block)
    validate_path(path)

    headers = add_puppet_headers('Accept' => 'application/octet-stream')
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

    handle_response_errors(response)

    return nil
  end

  def get_static_file_content(path:, environment:, code_id:, ssl_context: nil, &block)
    validate_path(path)

    headers = add_puppet_headers('Accept' => 'application/octet-stream')
    response = @client.get(
      with_base_url("/static_file_content#{path}"),
      headers: headers,
      params: {
        environment: environment.to_s,
        code_id: code_id,
      },
      ssl_context: ssl_context
    ) do |res|
      if res.success?
        res.read_body(&block)
      end
    end

    handle_response_errors(response)

    return nil
  end

  private

  def validate_path(path)
    raise ArgumentError, "Path must start with a slash" unless path =~ PATH_REGEX
  end
end
