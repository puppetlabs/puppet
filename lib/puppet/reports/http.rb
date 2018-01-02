require 'puppet'
require 'puppet/network/http_pool'
require 'uri'

Puppet::Reports.register_report(:http) do

  desc <<-DESC
    Send reports via HTTP or HTTPS. This report processor submits reports as
    POST requests to the address in the `reporturl` setting. When a HTTPS URL
    is used, the remote server must present a certificate issued by the Puppet
    CA or the connection will fail validation. The body of each POST request
    is the YAML dump of a Puppet::Transaction::Report object, and the
    Content-Type is set as `application/x-yaml`.
  DESC

  def process
    url = URI.parse(Puppet[:reporturl])
    headers = { "Content-Type" => "application/x-yaml" }
    # This metric_id option is silently ignored by Puppet's http client
    # (Puppet::Network::HTTP) but is used by Puppet Server's http client
    # (Puppet::Server::HttpClient) to track metrics on the request made to the
    # `reporturl` to store a report.
    options = { :metric_id => [:puppet, :report, :http] }
    if url.user && url.password
      options[:basic_auth] = {
        :user => url.user,
        :password => url.password
      }
    end
    use_ssl = url.scheme == 'https'
    conn = Puppet::Network::HttpPool.http_instance(url.host, url.port, use_ssl)
    response = conn.post(url.path, self.to_yaml, headers, options)
    unless response.kind_of?(Net::HTTPSuccess)
      Puppet.err _("Unable to submit report to %{url} [%{code}] %{message}") % { url: Puppet[:reporturl].to_s, code: response.code, message: response.msg }
    end
  end
end
