require 'openssl'
require 'net/http'

class Puppet::Network::HTTP::Factory
  @@openssl_initialized = false

  def initialize(verify)
    @verify = verify

    # PUP-1411, make sure that openssl is initialized before we try to connect
    if ! @@openssl_initialized
      OpenSSL::SSL::SSLContext.new
      @@openssl_initialized = true
    end
  end

  def create_connection(site)
    Puppet.debug("Creating new connection for #{site}")

    args = [site.host, site.port]
    if Puppet[:http_proxy_host] == "none"
      args << nil << nil
    else
      args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
    end

    http = Net::HTTP.new(*args)

    # REMIND: this probably isn't needed anymore
    # Pop open the http client a little; older versions of Net::HTTP(s) didn't
    # give us a reader for ca_file... Grr...
    class << http; attr_accessor :ca_file; end

    http.use_ssl = site.use_ssl?
    # Use configured timeout (#1176)
    http.read_timeout = Puppet[:configtimeout]
    http.open_timeout = Puppet[:configtimeout]

    @verify.setup_connection(http)

    http
  end
end
