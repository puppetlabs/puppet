# frozen_string_literal: true

require_relative '../../puppet'
require_relative '../../puppet/network/http_pool'
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
    options = {
      :metric_id => [:puppet, :report, :http],
      :include_system_store => Puppet[:report_include_system_store],
    }

    # Puppet's http client implementation accepts userinfo in the URL
    # but puppetserver's does not. So pass credentials explicitly.
    if url.user && url.password
      options[:basic_auth] = {
        user: url.user,
        password: url.password
      }
    end

    client = Puppet.runtime[:http]
    client.post(url, to_yaml, headers: headers, options: options) do |response|
      unless response.success?
        Puppet.err _("Unable to submit report to %{url} [%{code}] %{message}") % { url: Puppet[:reporturl].to_s, code: response.code, message: response.reason }
      end
    end
  end
end
