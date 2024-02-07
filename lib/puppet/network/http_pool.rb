# frozen_string_literal: true

require_relative '../../puppet/network/http/connection'

module Puppet::Network; end

# This module is deprecated.
#
# @api public
# @deprecated Use {Puppet::HTTP::Client} instead.
#
module Puppet::Network::HttpPool
  @http_client_class = Puppet::Network::HTTP::Connection

  def self.http_client_class
    @http_client_class
  end

  def self.http_client_class=(klass)
    @http_client_class = klass
  end

  # Retrieve a connection for the given host and port.
  #
  # @param host [String] The hostname to connect to
  # @param port [Integer] The port on the host to connect to
  # @param use_ssl [Boolean] Whether to use an SSL connection
  # @param verify_peer [Boolean] Whether to verify the peer credentials, if possible. Verification will not take place if the CA certificate is missing.
  # @return [Puppet::Network::HTTP::Connection]
  #
  # @deprecated Use {Puppet.runtime[:http]} instead.
  # @api public
  #
  def self.http_instance(host, port, use_ssl = true, verify_peer = true)
    Puppet.warn_once('deprecations', self, "The method 'Puppet::Network::HttpPool.http_instance' is deprecated. Use Puppet.runtime[:http] instead")

    if verify_peer
      verifier = Puppet::SSL::Verifier.new(host, nil)
    else
      ssl = Puppet::SSL::SSLProvider.new
      verifier = Puppet::SSL::Verifier.new(host, ssl.create_insecure_context)
    end
    http_client_class.new(host, port, use_ssl: use_ssl, verifier: verifier)
  end

  # Retrieve a connection for the given host and port.
  #
  # @param host [String] The host to connect to
  # @param port [Integer] The port to connect to
  # @param use_ssl [Boolean] Whether to use SSL, defaults to `true`.
  # @param ssl_context [Puppet::SSL:SSLContext, nil] The ssl context to use
  #   when making HTTPS connections. Required when `use_ssl` is `true`.
  # @return [Puppet::Network::HTTP::Connection]
  #
  # @deprecated Use {Puppet.runtime[:http]} instead.
  # @api public
  #
  def self.connection(host, port, use_ssl: true, ssl_context: nil)
    Puppet.warn_once('deprecations', self, "The method 'Puppet::Network::HttpPool.connection' is deprecated. Use Puppet.runtime[:http] instead")

    if use_ssl
      unless ssl_context
        # TRANSLATORS 'ssl_context' is an argument and should not be translated
        raise ArgumentError, _("An ssl_context is required when connecting to 'https://%{host}:%{port}'") % { host: host, port: port }
      end

      verifier = Puppet::SSL::Verifier.new(host, ssl_context)
      http_client_class.new(host, port, use_ssl: true, verifier: verifier)
    else
      if ssl_context
        # TRANSLATORS 'ssl_context' is an argument and should not be translated
        Puppet.warning(_("An ssl_context is unnecessary when connecting to 'http://%{host}:%{port}' and will be ignored") % { host: host, port: port })
      end

      http_client_class.new(host, port, use_ssl: false)
    end
  end
end
