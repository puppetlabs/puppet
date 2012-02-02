require 'puppet'
require 'net/http'
require 'net/https'
require 'uri'

Puppet::Reports.register_report(:http) do

  desc <<-DESC
  Send report information via HTTP to the `reporturl`. Each host sends
  its report as a YAML dump and this sends this YAML to a client via HTTP POST.
  The YAML is the `report` parameter of the request."
  DESC

  def process
    url = URI.parse(Puppet[:reporturl])
    http = Net::HTTP.new(url.host, url.port)

    if url.scheme == "https"
      http.use_ssl = true
      if Puppet[:reporturl_ssl_verify] == true
        http.ca_file = Puppet[:reporturl_ssl_cert]
        Puppet.warning "Report URL HTTPS certificate file does not exist: #{http.ca_file}" unless File.exists? http.ca_file
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    req = Net::HTTP::Post.new(url.path)
    req.body = self.to_yaml
    req.content_type = "application/x-yaml"

    http.start do |http|
      http.request(req)
    end

  end
end
