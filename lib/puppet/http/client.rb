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

  def get(url, headers: {}, params: {})
    connect(url) do |http|
      query = encode_params(params).join('&')
      path = "#{url.path}?#{query}"

      resp = http.get(path, @default_headers.merge(headers))
      Puppet.info("HTTP GET #{url} returned #{resp.code} #{resp.reason}")
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
