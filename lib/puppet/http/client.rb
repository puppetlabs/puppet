class Puppet::HTTP::Client
  def initialize(pool: Puppet::Network::HTTP::Pool.new, ssl_context:)
    @pool = pool
    @default_headers = {
      'X-Puppet-Version' => Puppet.version,
      'User-Agent' => Puppet[:http_user_agent],
    }.freeze
    @ssl_context = ssl_context
  end

  def connect(uri, &block)
    site = Puppet::Network::HTTP::Site.from_uri(uri)
    verifier = Puppet::SSL::Verifier.new(uri.host, @ssl_context)
    @pool.with_connection(site, verifier) do |http|
      if block_given?
        handle_post_connect(uri, http, &block)
      end
    end
  rescue Puppet::HTTP::HTTPError
    raise
  rescue => e
    raise Puppet::HTTP::ConnectionError.new(_("Failed to connect to %{uri}: %{message}") % {uri: uri, message: e.message}, e)
  end

  def get(url, headers: {}, params: {}, &block)
    response = nil

    connect(url) do |http|
      query = encode_params(params)
      path = "#{url.path}?#{query}"

      request = Net::HTTP::Get.new(path, @default_headers.merge(headers))
      http.request(request) do |nethttp|
        response = Puppet::HTTP::Response.new(nethttp)
        if block_given?
          yield response
        else
          response.read_body
        end
      end
    end

    Puppet.info("HTTP GET #{url} returned #{response.code} #{response.reason}")
    response
  end

  def put(url, headers: {}, params: {}, content_type:, body:)
    response = nil

    connect(url) do |http|
      query = encode_params(params)
      path = "#{url.path}?#{query}"

      request = Net::HTTP::Put.new(path, @default_headers.merge(headers))
      request.body = body
      request['Content-Length'] = body.bytesize
      request['Content-Type'] = content_type
      http.request(request) do |nethttp|
        response = Puppet::HTTP::Response.new(nethttp)
        if block_given?
          yield response
        else
          response.read_body
        end
      end
    end

    Puppet.info("HTTP PUT #{url} returned #{response.code} #{response.reason}")
    response
  end

  def close
    @pool.close
  end

  private

  def encode_params(params)
    params.map do |key, value|
      "#{key}=#{Puppet::Util.uri_query_encode(value.to_s)}"
    end.join('&')
  end

  def handle_post_connect(uri, http, &block)
    start = Time.now
    yield http
  rescue Puppet::HTTP::HTTPError
    raise
  rescue EOFError => e
    raise Puppet::HTTP::HTTPError.new(_("Request to %{uri} interrupted after %{elapsed} seconds") % {uri: uri, elapsed: elapsed(start)}, e)
  rescue Timeout::Error => e
    raise Puppet::HTTP::HTTPError.new(_("Request to %{uri} timed out after %{elapsed} seconds") % {uri: uri, elapsed: elapsed(start)}, e)
  rescue => e
    raise Puppet::HTTP::HTTPError.new(_("Request to %{uri} failed after %{elapsed} seconds: %{message}") % {uri: uri, elapsed: elapsed(start), message: e.message}, e)
  end

  def elapsed(start)
    (Time.now - start).to_f.round(3)
  end
end
