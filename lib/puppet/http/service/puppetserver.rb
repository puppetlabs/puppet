# frozen_string_literal: true

# The puppetserver service.
#
# @api public
#
class Puppet::HTTP::Service::Puppetserver < Puppet::HTTP::Service
  # Use `Puppet::HTTP::Session.route_to(:puppetserver)` to create or get an instance of this class.
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
    url = build_url('', server || Puppet[:server], port || Puppet[:serverport])
    super(client, session, url)
  end

  # Request the puppetserver's simple status.
  #
  # @param [Puppet::SSL::SSLContext] ssl_context to use when establishing
  # the connection.
  # @return Puppet::HTTP::Response The HTTP response
  #
  # @api public
  #
  def get_simple_status(ssl_context: nil)
    request_path = "/status/v1/simple/server"

    begin
      response = @client.get(
        with_base_url(request_path),
        headers: add_puppet_headers({}),
        options: { ssl_context: ssl_context }
      )

      process_response(response)
    rescue Puppet::HTTP::ResponseError => e
      if e.response.code == 404 && e.response.url.path == "/status/v1/simple/server"
        request_path = "/status/v1/simple/master"
        retry
      else
        raise e
      end
    end

    [response, response.body.to_s]
  end
end
