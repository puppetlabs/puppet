class Puppet::HTTP::Client
  def initialize(ssl_context:)
    @pool = Puppet::Network::HTTP::Pool.new
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
    connect(url) do |http|
      query = encode_params(params)
      path = "#{url.path}?#{query}"

      request = Net::HTTP::Get.new(path, @default_headers.merge(headers))

      if block_given?
        resp = nil
        http.request(request) do |nethttp|
          resp = Puppet::HTTP::StreamingResponse.new(nethttp)
          yield resp
        end
      else
        resp = Puppet::HTTP::Response.new(http.request(request))
      end

      Puppet.info("HTTP GET #{url} returned #{resp.code} #{resp.reason}")
      resp
    end
  end

  def put(url, headers: {}, params: {}, content_type:, body:)
    connect(url) do |http|
      query = encode_params(params)
      path = "#{url.path}?#{query}"

      request = Net::HTTP::Put.new(path, @default_headers.merge(headers))
      request.body = body
      request['Content-Length'] = body.bytesize
      request['Content-Type'] = content_type

      resp = Puppet::HTTP::Response.new(http.request(request))
      Puppet.info("HTTP PUT #{url} returned #{resp.code} #{resp.reason}")
      resp
    end
  end

  def close
    @pool.close
  end

  private

  def encode_params(params)
    params.map do |key, value|
      "#{key.to_s}=#{Puppet::Util.uri_query_encode(value.to_s)}"
    end.join('&')
  end
end
