class Puppet::HTTP::Service
  attr_reader :url

  def initialize(client, url)
    @client = client
    @url = url
  end

  def with_base_url(path)
    u = @url.dup
    u.path += path
    u
  end

  def connect(ssl_context: nil)
    @client.connect(@url, ssl_context: ssl_context)
  end
end
