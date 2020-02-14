class Puppet::HTTP::Service::Compiler < Puppet::HTTP::Service
  API = '/puppet/v3'.freeze

  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:server], port || Puppet[:masterport])
    super(client, session, url)
  end

  def get_node(name, environment:, configured_environment: nil, transaction_uuid: nil)
    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Node).join(', '))

    response = @client.get(
      with_base_url("/node/#{name}"),
      headers: headers,
      params: {
        environment: environment,
        configured_environment: configured_environment || environment,
        transaction_uuid: transaction_uuid,
      },
    )

    @session.process_response(response)

    return deserialize(response, Puppet::Node) if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end

  def get_catalog(name, facts:, environment:, configured_environment: nil, transaction_uuid: nil, job_uuid: nil, static_catalog: true, checksum_type: Puppet[:supported_checksum_types])
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

    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Resource::Catalog).join(', '))

    response = @client.post(
      with_base_url("/catalog/#{name}"),
      headers: headers,
      # for legacy reasons we always send environment as a query parameter too
      params: { environment: environment },
      content_type: 'application/x-www-form-urlencoded',
      body: body,
    )

    @session.process_response(response)

    return deserialize(response, Puppet::Resource::Catalog) if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end

  def put_facts(name, environment:, facts:)
    formatter = Puppet::Network::FormatHandler.format_for(Puppet[:preferred_serialization_format])

    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Node::Facts).join(', '))

    response = @client.put(
      with_base_url("/facts/#{name}"),
      headers: headers,
      params: { environment: environment },
      content_type: formatter.mime,
      body: serialize(formatter, facts),
    )

    @session.process_response(response)

    return true if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end
end
