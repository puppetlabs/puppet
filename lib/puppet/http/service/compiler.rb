# frozen_string_literal: true

# The Compiler service is used to submit and retrieve data from the
# puppetserver.
#
# @api public
class Puppet::HTTP::Service::Compiler < Puppet::HTTP::Service
  # @return [String] Default API for the Compiler service
  API = '/puppet/v3'

  # Use `Puppet::HTTP::Session.route_to(:puppet)` to create or get an instance of this class.
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

  # Submit a GET request to retrieve a node from the server.
  #
  # @param [String] name The name of the node being requested
  # @param [String] environment The name of the environment we are operating in
  # @param [String] configured_environment Optional, the name of the configured
  #   environment. If unset, `environment` is used.
  # @param [String] transaction_uuid An agent generated transaction uuid, used
  #   for connecting catalogs and reports.
  #
  # @return [Array<Puppet::HTTP::Response, Puppet::Node>] An array containing
  #   the request response and the deserialized requested node
  #
  # @api public
  def get_node(name, environment:, configured_environment: nil, transaction_uuid: nil)
    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Node).join(', '))

    response = @client.get(
      with_base_url("/node/#{name}"),
      headers: headers,
      params: {
        environment: environment,
        configured_environment: configured_environment || environment,
        transaction_uuid: transaction_uuid,
      }
    )

    process_response(response)

    [response, deserialize(response, Puppet::Node)]
  end

  # Submit a POST request to submit a catalog to the server.
  #
  # @param [String] name The name of the catalog to be submitted
  # @param [Puppet::Node::Facts] facts Facts for this catalog
  # @param [String] environment The name of the environment we are operating in
  # @param [String] configured_environment Optional, the name of the configured
  #   environment. If unset, `environment` is used.
  # @param [Boolean] check_environment If true, request that the server check if
  #   our `environment` matches the server-specified environment. If they do not
  #   match, then the server may return an empty catalog in the server-specified
  #   environment.
  # @param [String] transaction_uuid An agent generated transaction uuid, used
  #   for connecting catalogs and reports.
  # @param [String] job_uuid A unique job identifier defined when the orchestrator
  #   starts a puppet run via pxp-agent. This is used to correlate catalogs and
  #   reports with the orchestrator job.
  # @param [Boolean] static_catalog Indicates if the file metadata(s) are inlined
  #   in the catalog. This informs the agent if it needs to make a second request
  #   to retrieve metadata in addition to the initial catalog request.
  # @param [Array<String>] checksum_type An array of accepted checksum types.
  #
  # @return [Array<Puppet::HTTP::Response, Puppet::Resource::Catalog>] An array
  #   containing the request response and the deserialized catalog returned by
  #   the server
  #
  # @api public
  def post_catalog(name, facts:, environment:, configured_environment: nil, check_environment: false, transaction_uuid: nil, job_uuid: nil, static_catalog: true, checksum_type: Puppet[:supported_checksum_types])
    if Puppet[:preferred_serialization_format] == "pson"
      formatter = Puppet::Network::FormatHandler.format_for(:pson)
      # must use 'pson' instead of 'text/pson'
      facts_format = 'pson'
    else
      formatter = Puppet::Network::FormatHandler.format_for(:json)
      facts_format = formatter.mime
    end

    facts_as_string = serialize(formatter, facts)

    # query parameters are sent in the POST request body
    body = {
      facts_format: facts_format,
      facts: Puppet::Util.uri_query_encode(facts_as_string),
      environment: environment,
      configured_environment: configured_environment || environment,
      check_environment: !!check_environment,
      transaction_uuid: transaction_uuid,
      job_uuid: job_uuid,
      static_catalog: static_catalog,
      checksum_type: checksum_type.join('.')
    }.map do |key, value|
      "#{key}=#{Puppet::Util.uri_query_encode(value.to_s)}"
    end.join("&")

    headers = add_puppet_headers(
      'Accept' => get_mime_types(Puppet::Resource::Catalog).join(', '),
      'Content-Type' => 'application/x-www-form-urlencoded'
    )

    response = @client.post(
      with_base_url("/catalog/#{name}"),
      body,
      headers: headers,
      # for legacy reasons we always send environment as a query parameter too
      params: { environment: environment },
    )

    if (compiler = response['X-Puppet-Compiler-Name'])
      Puppet.notice("Catalog compiled by #{compiler}")
    end

    process_response(response)

    [response, deserialize(response, Puppet::Resource::Catalog)]
  end

  #
  # @api private
  #
  # Submit a POST request to request a catalog to the server using v4 endpoint
  #
  # @param [String] certname The name of the node for which to compile the catalog.
  # @param [Hash] persistent A hash containing two required keys, facts and catalog,
  #   which when set to true will cause the facts and reports to be stored in
  #   PuppetDB, or discarded if set to false.
  # @param [String] environment The name of the environment for which to compile the catalog.
  # @param [Hash] facts A hash with a required values key, containing a hash of all the
  #    facts for the node. If not provided, Puppet will attempt to fetch facts for the node
  #    from PuppetDB.
  # @param [Hash] trusted_facts A hash with a required values key containing a hash of
  #    the trusted facts for a node
  # @param [String] transaction_uuid The id for tracking the catalog compilation and
  #    report submission.
  # @param [String] job_id The id of the orchestrator job that triggered this run.
  # @param [Hash] options A hash of options beyond direct input to catalogs. Options:
  #    - prefer_requested_environment Whether to always override a node's classified
  #      environment with the one supplied in the request. If this is true and no environment
  #      is supplied, fall back to the classified environment, or finally, 'production'.
  #    - capture_logs Whether to return the errors and warnings that occurred during
  #      compilation alongside the catalog in the response body.
  #    - log_level The logging level to use during the compile when capture_logs is true.
  #      Options are 'err', 'warning', 'info', and 'debug'.
  #
  # @return [Array<Puppet::HTTP::Response, Puppet::Resource::Catalog, Array<String>>] An array
  #   containing the request response, the deserialized catalog returned by
  #   the server and array containing logs (log array will be empty if capture_logs is false)
  #
  def post_catalog4(certname, persistence:, environment:, facts: nil, trusted_facts: nil, transaction_uuid: nil, job_id: nil, options: nil)
    unless persistence.is_a?(Hash) && (missing = [:facts, :catalog] - persistence.keys.map(&:to_sym)).empty?
      raise ArgumentError, "The 'persistence' hash is missing the keys: #{missing.join(', ')}"
    end
    raise ArgumentError, "Facts must be a Hash not a #{facts.class}" unless facts.nil? || facts.is_a?(Hash)

    body = {
      certname: certname,
      persistence: persistence,
      environment: environment,
      transaction_uuid: transaction_uuid,
      job_id: job_id,
      options: options
    }
    body[:facts] = { values: facts } unless facts.nil?
    body[:trusted_facts] = { values: trusted_facts } unless trusted_facts.nil?
    headers = add_puppet_headers(
      'Accept' => get_mime_types(Puppet::Resource::Catalog).join(', '),
      'Content-Type' => 'application/json'
    )

    url = URI::HTTPS.build(host: @url.host, port: @url.port, path: Puppet::Util.uri_encode("/puppet/v4/catalog"))
    response = @client.post(
      url,
      body.to_json,
      headers: headers
    )
    process_response(response)
    begin
      response_body = JSON.parse(response.body)
      catalog = Puppet::Resource::Catalog.from_data_hash(response_body['catalog'])
    rescue => err
      raise Puppet::HTTP::SerializationError.new("Failed to deserialize catalog from puppetserver response: #{err.message}", err)
    end

    logs = response_body['logs'] || []
    [response, catalog, logs]
  end

  #
  # @api private
  #
  # Submit a GET request to retrieve the facts for the named node
  #
  # @param [String] name Name of the node to retrieve facts for
  # @param [String] environment Name of the environment we are operating in
  #
  # @return [Array<Puppet::HTTP::Response, Puppet::Node::Facts>] An array
  #   containing the request response and the deserialized facts for the
  #   specified node
  #
  # @api public
  def get_facts(name, environment:)
    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Node::Facts).join(', '))

    response = @client.get(
      with_base_url("/facts/#{name}"),
      headers: headers,
      params: { environment: environment }
    )

    process_response(response)

    [response, deserialize(response, Puppet::Node::Facts)]
  end

  # Submits a PUT request to submit facts for the node to the server.
  #
  # @param [String] name Name of the node we are submitting facts for
  # @param [String] environment Name of the environment we are operating in
  # @param [Puppet::Node::Facts] facts Facts for the named node
  #
  # @return [Puppet::HTTP::Response] The request response
  #
  # @api public
  def put_facts(name, environment:, facts:)
    formatter = Puppet::Network::FormatHandler.format_for(Puppet[:preferred_serialization_format])

    headers = add_puppet_headers(
      'Accept' => get_mime_types(Puppet::Node::Facts).join(', '),
      'Content-Type' => formatter.mime
    )

    response = @client.put(
      with_base_url("/facts/#{name}"),
      serialize(formatter, facts),
      headers: headers,
      params: { environment: environment },
    )

    process_response(response)

    response
  end

  # Submit a GET request to retrieve a file stored with filebucket.
  #
  # @param [String] path The request path, formatted by `Puppet::FileBucket::Dipper`
  # @param [String] environment Name of the environment we are operating in.
  #   This should not impact filebucket at all, but is included to be consistent
  #   with legacy code.
  # @param [String] bucket_path
  # @param [String] diff_with a checksum to diff against if we are comparing
  #   files that are both stored in the bucket
  # @param [String] list_all
  # @param [String] fromdate
  # @param [String] todate
  #
  # @return [Array<Puppet::HTTP::Response, Puppet::FileBucket::File>] An array
  #   containing the request response and the deserialized file returned from
  #   the server.
  #
  # @api public
  def get_filebucket_file(path, environment:, bucket_path: nil, diff_with: nil, list_all: nil, fromdate: nil, todate: nil)
    headers = add_puppet_headers('Accept' => 'application/octet-stream')

    response = @client.get(
      with_base_url("/file_bucket_file/#{path}"),
      headers: headers,
      params: {
        environment: environment,
        bucket_path: bucket_path,
        diff_with: diff_with,
        list_all: list_all,
        fromdate: fromdate,
        todate: todate
      }
    )

    process_response(response)

    [response, deserialize(response, Puppet::FileBucket::File)]
  end

  # Submit a PUT request to store a file with filebucket.
  #
  # @param [String] path The request path, formatted by `Puppet::FileBucket::Dipper`
  # @param [String] body The contents of the file to be backed
  # @param [String] environment Name of the environment we are operating in.
  #   This should not impact filebucket at all, but is included to be consistent
  #   with legacy code.
  #
  # @return [Puppet::HTTP::Response] The response request
  #
  # @api public
  def put_filebucket_file(path, body:, environment:)
    headers = add_puppet_headers({
                                   'Accept' => 'application/octet-stream',
                                   'Content-Type' => 'application/octet-stream'
                                 })

    response = @client.put(
      with_base_url("/file_bucket_file/#{path}"),
      body,
      headers: headers,
      params: {
        environment: environment
      }
    )

    process_response(response)

    response
  end

  # Submit a HEAD request to check the status of a file stored with filebucket.
  #
  # @param [String] path The request path, formatted by `Puppet::FileBucket::Dipper`
  # @param [String] environment Name of the environment we are operating in.
  #   This should not impact filebucket at all, but is included to be consistent
  #   with legacy code.
  # @param [String] bucket_path
  #
  # @return [Puppet::HTTP::Response] The request response
  #
  # @api public
  def head_filebucket_file(path, environment:, bucket_path: nil)
    headers = add_puppet_headers('Accept' => 'application/octet-stream')

    response = @client.head(
      with_base_url("/file_bucket_file/#{path}"),
      headers: headers,
      params: {
        environment: environment,
        bucket_path: bucket_path
      }
    )

    process_response(response)

    response
  end
end
