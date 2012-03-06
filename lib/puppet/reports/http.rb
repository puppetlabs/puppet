require 'puppet'
require 'puppet/network/http_pool'
require 'uri'

Puppet::Reports.register_report(:http) do

  desc <<-DESC
  Send report information via HTTP to the `reporturl`. Each host sends
  its report as a YAML dump and this sends this YAML to a client via HTTP POST.
  The YAML is the `report` parameter of the request."
  DESC

  def process
    url = URI.parse(Puppet[:reporturl])
    req = Net::HTTP::Post.new(url.path)
    req.body = self.to_yaml
    req.content_type = "application/x-yaml"
    conn = Puppet::Network::HttpPool.http_instance(url.host, url.port,
                                                   ssl=(url.scheme == 'https'))
    conn.start {|http|
      response = http.request(req)
      unless response.kind_of?(Net::HTTPSuccess)
        Puppet.err "Unable to submit report to #{Puppet[:reporturl].to_s} [#{response.code}] #{response.msg}"
      end
    }
  end
end
