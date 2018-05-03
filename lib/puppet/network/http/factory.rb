require 'openssl'
require 'net/http'
require 'puppet/util/http_proxy'

# Factory for <tt>Net::HTTP</tt> objects.
#
# Encapsulates the logic for creating a <tt>Net::HTTP</tt> object based on the
# specified {Puppet::Network::HTTP::Site Site} and puppet settings.
#
# @api private
#
class Puppet::Network::HTTP::Factory
  @@openssl_initialized = false

  KEEP_ALIVE_TIMEOUT = 2**31 - 1

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

    unless Puppet::Util::HttpProxy.no_proxy?(site)
      if Puppet[:http_proxy_host] == "none"
        args << nil << nil
      else
        args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
      end
    end

    http = Net::HTTP.new(*args)
    http.use_ssl = site.use_ssl?
    http.read_timeout = Puppet[:http_read_timeout]
    http.open_timeout = Puppet[:http_connect_timeout]
    http.keep_alive_timeout = KEEP_ALIVE_TIMEOUT if http.respond_to?(:keep_alive_timeout=)

    if Puppet[:sourceaddress]
      if http.respond_to?(:local_host)
        Puppet.debug("Using source IP #{Puppet[:sourceaddress]}")
        http.local_host = Puppet[:sourceaddress]
      else
        raise ArgumentError, "Setting 'sourceaddress' is unsupported by this version of Net::HTTP."
      end
    end

    if Puppet[:http_debug]
      http.set_debug_output($stderr)
    end

    http
  end
end
