class Puppet::HTTP::Service::Report < Puppet::HTTP::Service
  API = '/puppet/v3'.freeze

  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:report_server], port || Puppet[:report_port])
    super(client, session, url)
  end

  def put_report(name, report, environment:, ssl_context: nil)
    formatter = Puppet::Network::FormatHandler.format_for(Puppet[:preferred_serialization_format])
    headers = add_puppet_headers('Accept' => get_mime_types(Puppet::Transaction::Report).join(', '))

    response = @client.put(
      with_base_url("/report/#{name}"),
      headers: headers,
      params: { environment: environment },
      content_type: formatter.mime,
      body: serialize(formatter, report),
      ssl_context: ssl_context
    )

    # override parent's process_response handling
    @session.process_response(response)

    if response.success?
      response
    elsif !@session.supports?(:report, 'json') && Puppet[:preferred_serialization_format] != 'pson'
      #TRANSLATORS "pson", "preferred_serialization_format", and "puppetserver" should not be translated
      raise Puppet::HTTP::ProtocolError.new(_("To submit reports to a server running puppetserver %{server_version}, set preferred_serialization_format to pson") % { server_version: response[Puppet::HTTP::HEADER_PUPPET_VERSION]})
    else
      raise Puppet::HTTP::ResponseError.new(response)
    end
  end
end
