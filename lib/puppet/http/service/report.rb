# frozen_string_literal: true

# The Report service is used to submit run reports to the report server.
#
# @api public
#
class Puppet::HTTP::Service::Report < Puppet::HTTP::Service
  # @return [String] Default API for the report service
  API = '/puppet/v3'

  # Use `Puppet::HTTP::Session.route_to(:report)` to create or get an instance of this class.
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
  # @api private
  #
  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:report_server], port || Puppet[:report_port])
    super(client, session, url)
  end

  # Submit a report to the report server.
  #
  # @param [String] name the name of the report being submitted
  # @param [Puppet::Transaction::Report] report run report to be submitted
  # @param [String] environment name of the agent environment
  #
  # @return [Puppet::HTTP::Response] response returned by the server
  #
  # @api public
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
    else
      raise Puppet::HTTP::ResponseError, response
    end
  end
end
