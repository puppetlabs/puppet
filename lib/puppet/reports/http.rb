require 'puppet'
require 'puppet/network/http_pool'
require 'uri'

Puppet::Reports.register_report(:http) do

  desc <<-DESC
  Send report information via HTTP to the `reporturl`. Each host sends
  its report as a YAML dump and this sends this YAML to a client via HTTP POST.
  The YAML is the body of the request.
  DESC

  def process
    url = URI.parse(Puppet[:reporturl])
    timeout = Puppet[:reporturl_timeout]
    req = Net::HTTP::Post.new(url.path)
    req.body = self.to_yaml
    req.content_type = "application/x-yaml"
    conn = Puppet::Network::HttpPool.http_instance(url.host, url.port,
                                                   ssl=(url.scheme == 'https'))
    orig_read_timeout = conn.read_timeout
    orig_open_timeout = conn.open_timeout
    conn.read_timeout = timeout
    conn.open_timeout = timeout
    conn.start {|http|
      response = http.request(req)
      unless response.kind_of?(Net::HTTPSuccess)
        Puppet.err "Unable to submit report to #{Puppet[:reporturl].to_s} [#{response.code}] #{response.msg}"
      end
    }
  rescue Timeout::Error
      Puppet.err "Timeout when submitting report to #{Puppet[:reporturl].to_s}"
  ensure
    conn.read_timeout = orig_read_timeout
    conn.open_timeout = orig_open_timeout
  end
end
