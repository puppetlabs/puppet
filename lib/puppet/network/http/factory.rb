require 'openssl'
require 'net/http'

# Factory for <tt>Net::HTTP</tt> objects.
#
# Encapsulates the logic for creating a <tt>Net::HTTP</tt> object based on the
# specified {Puppet::Network::HTTP::Site Site} and puppet settings.
#
# @api private
#
class Puppet::Network::HTTP::Factory
  @@openssl_initialized = false

  def initialize
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
    http.use_ssl = site.use_ssl?
    # Use configured timeout (#1176)
    http.read_timeout = Puppet[:configtimeout]
    http.open_timeout = Puppet[:configtimeout]

    if Puppet[:http_debug]
      http.set_debug_output($stderr)
    end

    http
  end
end
