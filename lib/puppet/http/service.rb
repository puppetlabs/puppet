class Puppet::HTTP::Service
  attr_reader :url

  def initialize(client, url, ssl_context: nil)
    @client = client
    @url = url
    @ssl_context = ssl_context
  end

  def with_base_url(path)
    u = @url.dup
    u.path += path
    u
  end

  def connect
    @client.connect(@url, ssl_context: @ssl_context)
  end
end
