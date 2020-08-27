# The puppetserver service.
#
# @api private
#
class Puppet::HTTP::Service::Puppetserver < Puppet::HTTP::Service
  # @param [Puppet::HTTP::Client] client
  # @param [Puppet::HTTP::Session] session
  # @param [String] server If an explicit server is given,
  #   create a service using that server. If server is nil, the default value
  #   is used to create the service.
  # @param [Integer] port If an explicit port is given, create
  #   a service using that port. If port is nil, the default value is used to
  #   create the service.
  # @api private
  #
  def initialize(client, session, server, port)
    url = build_url('', server || Puppet[:server], port || Puppet[:masterport])
    super(client, session, url)
  end

  # Request the puppetserver's simple status
  #
  # @return Puppet::HTTP::Response The HTTP response
  # @api private
  #
  def get_simple_status
    response = @client.get(
      with_base_url("/status/v1/simple/master"),
      headers: add_puppet_headers({}),
    )

    process_response(response)

    [response, response.body.to_s]
  end
end
