require 'puppet/ssl/host'
require 'net/https'

module Puppet::Network; end

module Puppet::Network::HttpPool
  # Use the global localhost instance.
  def self.ssl_host
    Puppet::SSL::Host.localhost
  end

  # Use cert information from a Puppet client to set up the http object.
  def self.cert_setup(http)
    # Just no-op if we don't have certs.
    return false unless FileTest.exist?(Puppet[:hostcert]) and FileTest.exist?(Puppet[:localcacert])

    http.cert_store = ssl_host.ssl_store
    http.ca_file = Puppet[:localcacert]
    http.cert = ssl_host.certificate.content
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.key = ssl_host.key.content
  end

  # Retrieve a cached http instance if caching is enabled, else return
  # a new one.
  def self.http_instance(host, port, reset = false)
    args = [host, port]
    if Puppet[:http_proxy_host] == "none"
      args << nil << nil
    else
      args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
    end
    http = Net::HTTP.new(*args)

    # Pop open the http client a little; older versions of Net::HTTP(s) didn't
    # give us a reader for ca_file... Grr...
    class << http; attr_accessor :ca_file; end

    http.use_ssl = true
    # Use configured timeout (#1176)
    http.read_timeout = Puppet[:configtimeout]
    http.open_timeout = Puppet[:configtimeout]

    cert_setup(http)

    http
  end
end
