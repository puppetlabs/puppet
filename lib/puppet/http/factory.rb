# frozen_string_literal: true

require_relative '../../puppet/ssl/openssl_loader'
require 'net/http'
require_relative '../../puppet/http'

# Factory for `Net::HTTP` objects.
#
# Encapsulates the logic for creating a `Net::HTTP` object based on the
# specified {Site} and puppet settings.
#
# @api private
class Puppet::HTTP::Factory
  @@openssl_initialized = false

  KEEP_ALIVE_TIMEOUT = 2**31 - 1

  def initialize
    # PUP-1411, make sure that openssl is initialized before we try to connect
    unless @@openssl_initialized
      OpenSSL::SSL::SSLContext.new
      @@openssl_initialized = true
    end
  end

  def create_connection(site)
    Puppet.debug("Creating new connection for #{site}")

    http = Puppet::HTTP::Proxy.proxy(URI(site.addr))
    http.use_ssl = site.use_ssl?
    if site.use_ssl?
      http.min_version = OpenSSL::SSL::TLS1_VERSION if http.respond_to?(:min_version)
      http.ciphers = Puppet[:ciphers]
    end
    http.read_timeout = Puppet[:http_read_timeout]
    http.open_timeout = Puppet[:http_connect_timeout]
    http.keep_alive_timeout = KEEP_ALIVE_TIMEOUT if http.respond_to?(:keep_alive_timeout=)

    # 0 means make one request and never retry
    http.max_retries = 0

    if Puppet[:sourceaddress]
      Puppet.debug("Using source IP #{Puppet[:sourceaddress]}")
      http.local_host = Puppet[:sourceaddress]
    end

    if Puppet[:http_debug]
      http.set_debug_output($stderr)
    end

    http
  end
end
