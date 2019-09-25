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

  def close
    @pool.close
  end
end
