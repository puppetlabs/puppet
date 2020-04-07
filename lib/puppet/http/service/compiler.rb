#
# @api private
#
# The Compiler service is used to submit and retrieve data from the
# puppetserver.
#
class Puppet::HTTP::Service::Compiler < Puppet::HTTP::Service
  # @api private
  # @return [String] Default API for the Compiler service
  API = '/puppet/v3'.freeze

  #
  # @api private
  #
  # @param [Puppet::HTTP::Client] client
  # @param [Puppet::HTTP::Session] session
  # @param [String] server (Puppet[:ca_server]) If an explicit server is given,
  #   create a service using that server. If server is nil, the default value
  #   is used to create the service.
  # @param [Integer] port (Puppet[:ca_port]) If an explicit port is given, create
  #   a service using that port. If port is nil, the default value is used to
  #   create the service.
  #
  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:server], port || Puppet[:masterport])
    super(client, session, url)
  end

  #
  # @api private
  #
  # Submit a GET request to retrieve a node from the server
  #
  # @param [String] name The name of the node being requested
  # @param [String] environment The name of the environment we are operating in
  # @param [String] configured_environment Optional, the name of the configured
  #   environment. If unset, `environment` is used.
  # @param [String] transaction_uuid An agent generated transaction uuid, used
  #   for connecting catalogs and reports.
  #
  # @return [Puppet::Node] The deserialized requested node
  #
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

    deserialize(response, Puppet::Node)
  end

  #
  # @api private
  #
  # Submit a POST request to submit a catalog to the server
  #
  # @param [String] name The name of the catalog to be submitted
  # @param [Puppet::Node::Facts] facts Facts for this catalog
  # @param [String] environment The name of the environment we are operating in
  # @param [String] configured_environment Optional, the name of the configured
  #   environment. If unset, `environment` is used.
  # @param [String] transaction_uuid An agent generated transaction uuid, used
  #   for connecting catalogs and reports.
  # @param [String] job_uuid A unique job identifier defined when the orchestrator
  #   starts a puppet run via pxp-agent. This is used to correlate catalogs and
  #   reports with the orchestrator job.
  # @param [Boolean] static_catalog Indicates if the file metadata(s) are inlined
  #   in the catalog. This informs the agent if it needs to make a second request
  #   to retrieve metadata in addition to the initial catalog request.
  # @param [Array<String>] checksum_type An array of accepted checksum type.
  #   Currently defaults to `["md5", "sha256", "sha384", "sha512", "sha224"]`,
  #   or `["sha256", "sha384", "sha512", "sha224"]` if fips is enabled.
  #
  # @return [Puppet::Resource::Catalog] The deserialized catalog returned by
  #   the server
  #
  def post_catalog(name, facts:, environment:, configured_environment: nil, transaction_uuid: nil, job_uuid: nil, static_catalog: true, checksum_type: Puppet[:supported_checksum_types])
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
      headers: headers,
      # for legacy reasons we always send environment as a query parameter too
      params: { environment: environment },
      options: {
        body: body
      }
    )

    process_response(response)

    deserialize(response, Puppet::Resource::Catalog)
  end

  #
  # @api private
  #
  # Submit a GET request to retrieve the facts for the named node
  #
  # @param [String] name Name of the node to retrieve facts for
  # @param [String] environment Name of the environment we are operating in
  #
  # @return [Puppet::Node::Facts] Deserialized facts for the specified node
  #
  def get_facts(name, environment:)
    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Node::Facts).join(', '))

    response = @client.get(
      with_base_url("/facts/#{name}"),
      headers: headers,
      params: { environment: environment }
    )

    process_response(response)

    deserialize(response, Puppet::Node::Facts)
  end

  #
  # @api private
  #
  # Submits a PUT request to submit facts for the node to the server
  #
  # @param [String] name Name of the node we are submitting facts for
  # @param [String] environment Name of the environment we are operating in
  # @param [Puppet::Node::Facts] facts Facts for the named node
  #
  # @return [Boolean] Returns true unless an error is raised
  #
  def put_facts(name, environment:, facts:)
    formatter = Puppet::Network::FormatHandler.format_for(Puppet[:preferred_serialization_format])

    headers = add_puppet_headers(
      'Accept' => get_mime_types(Puppet::Node::Facts).join(', '),
      'Content-Type' => formatter.mime
    )

    response = @client.put(
      with_base_url("/facts/#{name}"),
      headers: headers,
      params: { environment: environment },
      options: {
        body: serialize(formatter, facts)
      }
    )

    process_response(response)

    true
  end

  #
  # @api private
  #
  # Submit a GET request to find the status of a compiler
  #
  # @param [String] name The name of the node that a status being requested for
  #
  # @return [Puppet::Status] The deserialized status returned from the server
  #
  def get_status(name)
    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Status).join(', '))

    response = @client.get(
      with_base_url("/status/#{name}"),
      headers: headers,
      params: {
        # environment is required, but meaningless, default to production
        environment: 'production'
      },
    )

    process_response(response)

    deserialize(response, Puppet::Status)
  end
end
