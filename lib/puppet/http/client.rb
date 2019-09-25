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
      yield http if block_given?
    end
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
end
