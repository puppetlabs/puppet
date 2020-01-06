class Puppet::HTTP::Service::Ca < Puppet::HTTP::Service
  HEADERS = { 'Accept' => 'text/plain' }.freeze
  API = '/puppet-ca/v1'.freeze

  def initialize(client, server, port)
    url = build_url(API, server || Puppet[:ca_server], port || Puppet[:ca_port])
    super(client, url)
  end

  def get_certificate(name, ssl_context: nil)
    response = @client.get(
      with_base_url("/certificate/#{name}"),
      headers: add_puppet_headers(HEADERS),
      ssl_context: ssl_context
    )

    return response.body.to_s if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end

  def get_certificate_revocation_list(if_modified_since: nil, ssl_context: nil)
    request_headers = if if_modified_since
                        h = add_puppet_headers(HEADERS).dup
                        h['If-Modified-Since'] = if_modified_since.httpdate
                        h
                      else
                        add_puppet_headers(HEADERS)
                      end

    response = @client.get(
      with_base_url("/certificate_revocation_list/ca"),
      headers: request_headers,
      ssl_context: ssl_context
    )

    return response.body.to_s if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end

  def put_certificate_request(name, csr, ssl_context: nil)
    response = @client.put(
      with_base_url("/certificate_request/#{name}"),
      headers: add_puppet_headers(HEADERS),
      content_type: 'text/plain',
      body: csr.to_pem,
      ssl_context: ssl_context
    )

    return response.body.to_s if response.success?

    raise Puppet::HTTP::ResponseError.new(response)
  end
end
