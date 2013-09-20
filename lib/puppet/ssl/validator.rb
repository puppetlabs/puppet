require 'puppet/ssl'
require 'openssl'
module Puppet
module SSL
class Validator
  attr_reader :peer_certs
  attr_reader :verify_errors
  attr_reader :ssl_configuration

  ##
  # @param [Hash] opts the options to initialze the instance with.
  #
  # @option opts [Puppet::SSL::Configuration] :ssl_configuration to use for
  #   authorizing the peer certificate chain.
  def initialize(opts = {})
    reset!
    @ssl_configuration = opts[:ssl_configuration] or raise ArgumentError, ":ssl_configuration is required"
  end

  ##
  # reset to the initial state.
  def reset!
    @peer_certs = []
    @verify_errors = []
  end

  ##
  # call performs verification of the SSL connection and collection of the
  # certificates for use in constructing the error message if the verification
  # failed.  This callback will be executed once for each certificate in a
  # chain being verified.
  #
  # From the [OpenSSL
  # documentation](http://www.openssl.org/docs/ssl/SSL_CTX_set_verify.html):
  # The `verify_callback` function is used to control the behaviour when the
  # SSL_VERIFY_PEER flag is set. It must be supplied by the application and
  # receives two arguments: preverify_ok indicates, whether the verification of
  # the certificate in question was passed (preverify_ok=1) or not
  # (preverify_ok=0). x509_ctx is a pointer to the complete context used for
  # the certificate chain verification.
  #
  # See {Puppet::Network::HTTP::Connection} for more information and where this
  # class is intended to be used.
  #
  # @param [Boolean] preverify_ok indicates whether the verification of the
  #   certificate in question was passed (preverify_ok=true)
  # @param [OpenSSL::SSL::SSLContext] ssl_context holds the SSLContext for the
  #   chain being verified.
  #
  # @return [Boolean] false if the peer is invalid, true otherwise.
  def call(preverify_ok, ssl_context)
    # We must make a copy since the scope of the ssl_context will be lost
    # across invocations of this method.
    current_cert = ssl_context.current_cert
    @peer_certs << Puppet::SSL::Certificate.from_instance(current_cert)

    if preverify_ok
      # If we've copied all of the certs in the chain out of the SSL library
      if @peer_certs.length == ssl_context.chain.length
        # (#20027) The peer cert must be issued by a specific authority
        preverify_ok = valid_peer?
      end
    else
      if ssl_context.error_string
        @verify_errors << "#{ssl_context.error_string} for #{current_cert.subject}"
      end
    end
    preverify_ok
  rescue => ex
    @verify_errors << ex.message
    false
  end

  ##
  # Register the instance's call method with the connection.
  #
  # @param [Net::HTTP] connection The connection to velidate
  #
  # @return [void]
  def register_verify_callback(connection)
    connection.verify_callback = self
  end

  ##
  # Validate the peer certificates against the authorized certificates.
  def valid_peer?
    descending_cert_chain = @peer_certs.reverse.map {|c| c.content }
    authz_ca_certs = ssl_configuration.ca_auth_certificates

    if not has_authz_peer_cert(descending_cert_chain, authz_ca_certs)
      msg = "The server presented a SSL certificate chain which does not include a " <<
        "CA listed in the ssl_client_ca_auth file.  "
      msg << "Authorized Issuers: #{authz_ca_certs.collect {|c| c.subject}.join(', ')}  " <<
        "Peer Chain: #{descending_cert_chain.collect {|c| c.subject}.join(' => ')}"
      @verify_errors << msg
      false
    else
      true
    end
  end

  ##
  # checks if the set of peer_certs contains at least one certificate issued
  # by a certificate listed in authz_certs
  #
  # @return [Boolean]
  def has_authz_peer_cert(peer_certs, authz_certs)
    peer_certs.any? do |peer_cert|
      authz_certs.any? do |authz_cert|
        peer_cert.verify(authz_cert.public_key)
      end
    end
  end
end
end
end
