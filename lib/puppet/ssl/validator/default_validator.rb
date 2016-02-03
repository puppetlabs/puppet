require 'openssl'
require 'puppet/ssl'

# Perform peer certificate verification against the known CA.
# If there is no CA information known, then no verification is performed
#
# @api private
#
class Puppet::SSL::Validator::DefaultValidator #< class Puppet::SSL::Validator
  attr_reader :peer_certs
  attr_reader :verify_errors
  attr_reader :ssl_configuration

  FIVE_MINUTES_AS_SECONDS = 5 * 60

  # Creates a new DefaultValidator, optionally with an SSL Configuration and SSL Host.
  #
  # @param ssl_configuration [Puppet::SSL::Configuration] (a default configuration) ssl_configuration the SSL configuration to use
  # @param ssl_host [Puppet::SSL::Host] (Puppet::SSL::Host.localhost) the SSL host to use
  #
  # @api private
  #
  def initialize(
      ssl_configuration = Puppet::SSL::Configuration.new(
                                        Puppet[:localcacert], {
                                          :ca_auth_file  => Puppet[:ssl_client_ca_auth]
                                        }),
      ssl_host = Puppet::SSL::Host.localhost)

    reset!
    @ssl_configuration = ssl_configuration
    @ssl_host = ssl_host
  end


  # Resets this validator to its initial validation state. The ssl configuration is not changed.
  #
  # @api private
  #
  def reset!
    @peer_certs = []
    @verify_errors = []
  end

  # Performs verification of the SSL connection and collection of the
  # certificates for use in constructing the error message if the verification
  # failed.  This callback will be executed once for each certificate in a
  # chain being verified.
  #
  # From the [OpenSSL
  # documentation](https://www.openssl.org/docs/ssl/SSL_CTX_set_verify.html):
  # The `verify_callback` function is used to control the behaviour when the
  # SSL_VERIFY_PEER flag is set. It must be supplied by the application and
  # receives two arguments: preverify_ok indicates, whether the verification of
  # the certificate in question was passed (preverify_ok=1) or not
  # (preverify_ok=0). x509_store_ctx is a pointer to the complete context used for
  # the certificate chain verification.
  #
  # See {Puppet::Network::HTTP::Connection} for more information and where this
  # class is intended to be used.
  #
  # @param [Boolean] preverify_ok indicates whether the verification of the
  #   certificate in question was passed (preverify_ok=true)
  # @param [OpenSSL::X509::StoreContext] store_context holds the X509 store context
  #   for the chain being verified.
  #
  # @return [Boolean] false if the peer is invalid, true otherwise.
  #
  # @api private
  #
  def call(preverify_ok, store_context)
    # We must make a copy since the scope of the store_context will be lost
    # across invocations of this method.
    if preverify_ok
      current_cert = store_context.current_cert
      @peer_certs << Puppet::SSL::Certificate.from_instance(current_cert)

      # If we've copied all of the certs in the chain out of the SSL library
      if @peer_certs.length == store_context.chain.length
        # (#20027) The peer cert must be issued by a specific authority
        preverify_ok = valid_peer?
      end
    else
      error = store_context.error || 0
      error_string = store_context.error_string || "OpenSSL error #{error}"

      case error
      when OpenSSL::X509::V_ERR_CRL_NOT_YET_VALID
        # current_crl can be nil
        # https://github.com/ruby/ruby/blob/ruby_1_9_3/ext/openssl/ossl_x509store.c#L501-L510
        crl = store_context.current_crl
        if crl
          if crl.last_update && crl.last_update < Time.now + FIVE_MINUTES_AS_SECONDS
            Puppet.debug("Ignoring CRL not yet valid, current time #{Time.now.utc}, CRL last updated #{crl.last_update.utc}")
            preverify_ok = true
          else
            @verify_errors << "#{error_string} for #{crl.issuer}"
          end
        else
          @verify_errors << error_string
        end
      else
        current_cert = store_context.current_cert
        @verify_errors << "#{error_string} for #{current_cert.subject}"
      end
    end
    preverify_ok
  rescue => ex
    @verify_errors << ex.message
    false
  end

  # Registers the instance's call method with the connection.
  #
  # @param [Net::HTTP] connection The connection to validate
  #
  # @return [void]
  #
  # @api private
  #
  def setup_connection(connection)
    if ssl_certificates_are_present?
      connection.cert_store = @ssl_host.ssl_store
      connection.ca_file = @ssl_configuration.ca_auth_file
      connection.cert = @ssl_host.certificate.content
      connection.key = @ssl_host.key.content
      connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
      connection.verify_callback = self
    else
      connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

  # Validates the peer certificates against the authorized certificates.
  #
  # @api private
  #
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

  # Checks if the set of peer_certs contains at least one certificate issued
  # by a certificate listed in authz_certs
  #
  # @return [Boolean]
  #
  # @api private
  #
  def has_authz_peer_cert(peer_certs, authz_certs)
    peer_certs.any? do |peer_cert|
      authz_certs.any? do |authz_cert|
        peer_cert.verify(authz_cert.public_key)
      end
    end
  end

  # @api private
  #
  def ssl_certificates_are_present?
    Puppet::FileSystem.exist?(Puppet[:hostcert]) && Puppet::FileSystem.exist?(@ssl_configuration.ca_auth_file)
  end
end
