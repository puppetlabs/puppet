# frozen_string_literal: true

# The CA service is used to handle certificate related REST requests.
#
# @api public
class Puppet::HTTP::Service::Ca < Puppet::HTTP::Service
  # @return [Hash] default headers for the ca service
  HEADERS = { 'Accept' => 'text/plain' }.freeze

  # @return [String] default API for the ca service
  API = '/puppet-ca/v1'

  # Use `Puppet::HTTP::Session.route_to(:ca)` to create or get an instance of this class.
  #
  # @param [Puppet::HTTP::Client] client
  # @param [Puppet::HTTP::Session] session
  # @param [String] server (`Puppet[:ca_server]`) If an explicit server is given,
  #   create a service using that server. If server is nil, the default value
  #   is used to create the service.
  # @param [Integer] port (`Puppet[:ca_port]`) If an explicit port is given, create
  #   a service using that port. If port is nil, the default value is used to
  #   create the service.
  #
  def initialize(client, session, server, port)
    url = build_url(API, server || Puppet[:ca_server], port || Puppet[:ca_port])
    super(client, session, url)
  end

  # Submit a GET request to retrieve the named certificate from the server.
  #
  # @param [String] name name of the certificate to request
  # @param [Time] if_modified_since If not nil, only download the cert if it has
  #   been modified since the specified time.
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [Array<Puppet::HTTP::Response, String>] An array containing the
  #   request response and the stringified body of the request response
  #
  # @api public
  def get_certificate(name, if_modified_since: nil, ssl_context: nil)
    headers = add_puppet_headers(HEADERS)
    headers['If-Modified-Since'] = if_modified_since.httpdate if if_modified_since

    response = @client.get(
      with_base_url("/certificate/#{name}"),
      headers: headers,
      options: { ssl_context: ssl_context }
    )

    process_response(response)

    [response, response.body.to_s]
  end

  # Submit a GET request to retrieve the certificate revocation list from the
  #   server.
  #
  # @param [Time] if_modified_since If not nil, only download the CRL if it has
  #   been modified since the specified time.
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [Array<Puppet::HTTP::Response, String>] An array containing the
  #   request response and the stringified body of the request response
  #
  # @api public
  def get_certificate_revocation_list(if_modified_since: nil, ssl_context: nil)
    headers = add_puppet_headers(HEADERS)
    headers['If-Modified-Since'] = if_modified_since.httpdate if if_modified_since

    response = @client.get(
      with_base_url("/certificate_revocation_list/ca"),
      headers: headers,
      options: { ssl_context: ssl_context }
    )

    process_response(response)

    [response, response.body.to_s]
  end

  # Submit a PUT request to send a certificate request to the server.
  #
  # @param [String] name The name of the certificate request being sent
  # @param [OpenSSL::X509::Request] csr Certificate request to send to the
  #   server
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [Puppet::HTTP::Response] The request response
  #
  # @api public
  def put_certificate_request(name, csr, ssl_context: nil)
    headers = add_puppet_headers(HEADERS)
    headers['Content-Type'] = 'text/plain'

    response = @client.put(
      with_base_url("/certificate_request/#{name}"),
      csr.to_pem,
      headers: headers,
      options: {
        ssl_context: ssl_context
      }
    )

    process_response(response)

    response
  end

  # Submit a POST request to send a certificate renewal request to the server
  #
  # @param [Puppet::SSL::SSLContext] ssl_context
  #
  # @return [Array<Puppet::HTTP::Response, String>] The request response
  #
  # @api public
  def post_certificate_renewal(ssl_context)
    headers = add_puppet_headers(HEADERS)
    headers['Content-Type'] = 'text/plain'

    response = @client.post(
      with_base_url('/certificate_renewal'),
      '', # Puppet::HTTP::Client.post requires a body, the API endpoint does not
      headers: headers,
      options: { ssl_context: ssl_context }
    )

    raise ArgumentError, _('SSL context must contain a client certificate.') unless ssl_context.client_cert

    process_response(response)

    [response, response.body.to_s]
  end
end
