# frozen_string_literal: true

require_relative '../../../puppet/file_serving/metadata'

# The FileServer service is used to retrieve file metadata and content.
#
# @api public
#
class Puppet::HTTP::Service::FileServer < Puppet::HTTP::Service
  # @return [String] Default API for the FileServer service
  API = '/puppet/v3'

  # @return [RegEx] RegEx used to determine if a path contains a leading slash
  PATH_REGEX = %r{^/}

  # Use `Puppet::HTTP::Session.route_to(:fileserver)` to create or get an instance of this class.
  #
  # @param [Puppet::HTTP::Client] client
  # @param [Puppet::HTTP::Session] session
  # @param [String] server (`Puppet[:server]`) If an explicit server is given,
  #   create a service using that server. If server is nil, the default value
  #   is used to create the service.
  # @param [Integer] port (`Puppet[:masterport]`) If an explicit port is given, create
  #   a service using that port. If port is nil, the default value is used to
  #   create the service.
  #
  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:server], port || Puppet[:serverport])
    super(client, session, url)
  end

  # Submit a GET request to the server to retrieve the metadata for a specified file.
  #
  # @param [String] path path to the file to retrieve data from
  # @param [String] environment the name of the environment we are operating in
  # @param [Symbol] links Can be one of either `:follow` or `:manage`, defines
  #   how links are handled.
  # @param [String] checksum_type The digest algorithm used to verify the file.
  #   Defaults to `sha256`.
  # @param [Symbol] source_permissions Can be one of `:use`, `:use_when_creating`,
  #   or `:ignore`. This parameter tells the server if it should include the
  #   file permissions in the response. If set to `:ignore`, the server will
  #   return default permissions.
  #
  # @return [Array<Puppet::HTTP::Response, Puppet::FileServing::Metadata>] An
  #   array with the request response and the deserialized metadata for the
  #   file returned from the server
  #
  # @api public
  #
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

    [response, deserialize(response, Puppet::FileServing::Metadata)]
  end

  # Submit a GET request to the server to retrieve the metadata for multiple files
  #
  # @param [String] path path to the file(s) to retrieve data from
  # @param [String] environment the name of the environment we are operating in
  # @param [Symbol] recurse  Can be `:true`, `:false`, or `:remote`. Defines if
  #   we recursively return the contents of the directory. Used in conjunction
  #   with `:recurselimit`. See the reference documentation for the file type
  #   for more details.
  # @param [Integer] recurselimit When `recurse` is set, `recurselimit` defines
  #   how far Puppet should descend into subdirectories. `0` is effectively the
  #   same as `recurse => false`, `1` will return files and directories directly
  #   inside the defined directory, `2` will return the direct content of the
  #   directory as well as the contents of the _first_ level of subdirectories.
  #   The pattern continues for each incremental value. See the reference
  #   documentation for the file type for more details.
  # @param [Array<String>] ignore An optional array of files to ignore, ie `['CVS', '.git', '.hg']`
  # @param [Symbol] links Can be one of either `:follow` or `:manage`, defines
  #   how links are handled.
  # @param [String] checksum_type The digest algorithm used to verify the file.
  #   Currently if fips is enabled, this defaults to `sha256`. Otherwise, it's `md5`.
  # @param [Symbol] source_permissions Can be one of `:use`, `:use_when_creating`,
  #   or `:ignore`. This parameter tells the server if it should include the
  #   file permissions in the report. If set to `:ignore`, the server will return
  #   default permissions.
  #
  # @return [Array<Puppet::HTTP::Response, Array<Puppet::FileServing::Metadata>>]
  #   An array with the request response and an array of the deserialized
  #   metadata for each file returned from the server
  #
  # @api public
  #
  def get_file_metadatas(environment:, path: nil, recurse: :false, recurselimit: nil, max_files: nil, ignore: nil, links: :manage, checksum_type: Puppet[:digest_algorithm], source_permissions: :ignore) # rubocop:disable Lint/BooleanSymbol
    validate_path(path)

    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::FileServing::Metadata).join(', '))

    response = @client.get(
      with_base_url("/file_metadatas#{path}"),
      headers: headers,
      params: {
        recurse: recurse,
        recurselimit: recurselimit,
        max_files: max_files,
        ignore: ignore,
        links: links,
        checksum_type: checksum_type,
        source_permissions: source_permissions,
        environment: environment,
      }
    )

    process_response(response)

    [response, deserialize_multiple(response, Puppet::FileServing::Metadata)]
  end

  # Submit a GET request to the server to retrieve content of a file.
  #
  # @param [String] path path to the file to retrieve data from
  # @param [String] environment the name of the environment we are operating in
  #
  # @yield [Sting] Yields the body of the response returned from the server
  #
  # @return [Puppet::HTTP::Response] The request response
  #
  # @api public
  #
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

    response
  end

  # Submit a GET request to retrieve file content using the `static_file_content` API
  # uniquely identified by (`code_id`, `environment`, `path`).
  #
  # @param [String] path path to the file to retrieve data from
  # @param [String] environment the name of the environment we are operating in
  # @param [String] code_id Defines the version of the resource to return
  #
  # @yield [String] Yields the body of the response returned
  #
  # @return [Puppet::HTTP::Response] The request response
  #
  # @api public
  #
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

    response
  end

  private

  def validate_path(path)
    raise ArgumentError, "Path must start with a slash" unless path =~ PATH_REGEX
  end
end
