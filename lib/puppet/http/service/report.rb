#
# @api private
#
# The Report service is used to submit run reports to the report server
#
class Puppet::HTTP::Service::Report < Puppet::HTTP::Service

  # @api private
  # @return [String] Default API for the report service
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
    url = build_url(API, server || Puppet[:report_server], port || Puppet[:report_port])
    super(client, session, url)
  end

  #
  # @api private
  #
  # Submit a report to the report server
  #
  # @param [String] name the name of the report being submitted
  # @param [Puppet::Transaction::Report] report run report to be submitted
  # @param [String] environment name of the agent environment
  #
  # @return [Puppet::HTTP::Response] response returned by the server
  #
  def put_report(name, report, environment:)
    formatter = Puppet::Network::FormatHandler.format_for(Puppet[:preferred_serialization_format])
    headers = add_puppet_headers(
      'Accept' => get_mime_types(Puppet::Transaction::Report).join(', '),
      'Content-Type' => formatter.mime
    )

    response = @client.put(
      with_base_url("/report/#{name}"),
      serialize(formatter, report),
      headers: headers,
      params: { environment: environment },
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
