require 'puppet/file_serving/metadata'

class Puppet::HTTP::Service::FileServer < Puppet::HTTP::Service
  API = '/puppet/v3'.freeze
  PATH_REGEX = /^\//

  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:server], port || Puppet[:masterport])
    super(client, session, url)
  end

  def get_file_metadata(path:, environment:, links: :manage, checksum_type: Puppet[:digest_algorithm], source_permissions: :ignore)
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
      }
    )

    process_response(response)

    deserialize(response, Puppet::FileServing::Metadata)
  end

  def get_file_metadatas(path: nil, environment:, recurse: :false, recurselimit: nil, ignore: nil, links: :manage, checksum_type: Puppet[:digest_algorithm], source_permissions: :ignore)
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
      }
    )

    process_response(response)

    deserialize_multiple(response, Puppet::FileServing::Metadata)
  end

  def get_file_content(path:, environment:, &block)
    validate_path(path)

    headers = add_puppet_headers('Accept' => 'application/octet-stream')
    response = @client.get(
      with_base_url("/file_content#{path}"),
      headers: headers,
      params: {
        environment: environment
      }
    ) do |res|
      if res.success?
        res.read_body(&block)
      end
    end

    process_response(response)

    nil
  end

  def get_static_file_content(path:, environment:, code_id:, &block)
    validate_path(path)

    headers = add_puppet_headers('Accept' => 'application/octet-stream')
    response = @client.get(
      with_base_url("/static_file_content#{path}"),
      headers: headers,
      params: {
        environment: environment,
        code_id: code_id,
      }
    ) do |res|
      if res.success?
        res.read_body(&block)
      end
    end

    process_response(response)

    nil
  end

  private

  def validate_path(path)
    raise ArgumentError, "Path must start with a slash" unless path =~ PATH_REGEX
  end
end
