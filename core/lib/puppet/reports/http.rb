require 'puppet'
require 'puppet/network/http_pool'
require 'uri'

Puppet::Reports.register_report(:http) do

  desc <<-DESC
    Send reports via HTTP or HTTPS. This report processor submits reports as
    POST requests to the address in the `reporturl` setting. The body of each POST
    request is the YAML dump of a Puppet::Transaction::Report object, and the
    Content-Type is set as `application/x-yaml`.
  DESC

  def process
    url = URI.parse(Puppet[:reporturl])
    body = self.to_yaml
    headers = { "Content-Type" => "application/x-yaml" }
    use_ssl = url.scheme == 'https'
    conn = Puppet::Network::HttpPool.http_instance(url.host, url.port, use_ssl)
    response = conn.post(url.path, body, headers)
    unless response.kind_of?(Net::HTTPSuccess)
      Puppet.err "Unable to submit report to #{Puppet[:reporturl].to_s} [#{response.code}] #{response.msg}"
    end
  end
end
