require 'puppet/ssl'

# Verify an SSL connection.
#
# @api private
class Puppet::SSL::Verifier

  FIVE_MINUTES_AS_SECONDS = 5 * 60

  attr_reader :ssl_context

  # Create a verifier using an `ssl_context`.
  #
  # @param hostname [String] FQDN of the server we're attempting to connect to
  # @param ssl_context [Puppet::SSL::SSLContext] ssl_context containing CA certs,
  #   CRLs, etc needed to verify the server's certificate chain
  def initialize(hostname, ssl_context)
    @hostname = hostname
    @ssl_context = ssl_context
  end

  # Return true if `self` is reusable with `verifier` meaning they
  # are using the same `ssl_context`, so there's no loss of security
  # when using a cached connection.
  #
  # @param verifier [Puppet::SSL::Verifier] the verifier to compare against
  # @return [Boolean] return true if a cached connection can be used, false otherwise
  def reusable?(verifier)
    verifier.instance_of?(self.class) &&
      verifier.ssl_context.object_id == @ssl_context.object_id
  end

  # Configure the `http` connection based on the current `ssl_context`.
  #
  # @param http [Net::HTTP] connection
  # @api private
  def setup_connection(http)
    http.cert_store = @ssl_context[:store]
    http.cert = @ssl_context[:client_cert]
    http.key = @ssl_context[:private_key]
    # default to VERIFY_PEER
    http.verify_mode = if !@ssl_context[:verify_peer]
                         OpenSSL::SSL::VERIFY_NONE
                       else
                         OpenSSL::SSL::VERIFY_PEER
                       end
    http.verify_callback = self
  end

  # This method is called if `Net::HTTP#start` raises an exception, which
  # could be a result of an openssl error during cert verification, due
  # to ruby's `Socket#post_connection_check`, or general SSL connection
  # error.
  #
  # @param http [Net::HTTP] connection
  # @param error [OpenSSL::SSL::SSLError] connection error
  # @raise [Puppet::SSL::CertVerifyError] SSL connection failed due to a
  #   verification error with the server's certificate or chain
  # @raise [Puppet::Error] server hostname does not match certificate
  # @raise [OpenSSL::SSL::SSLError] low-level SSL connection failure
  # @api private
  def handle_connection_error(http, error)
    raise @last_error if @last_error

    # ruby can pass SSL validation but fail post_connection_check
    peer_cert = http.peer_cert
    if peer_cert && !OpenSSL::SSL.verify_certificate_identity(peer_cert, @hostname)
      raise Puppet::SSL::CertMismatchError.new(peer_cert, @hostname)
    else
      raise error
    end
  end

  # OpenSSL will call this method with the verification result for each cert in
  # the server's chain, working from the root CA to the server's cert. If
  # preverify_ok is `true`, then that cert passed verification. If it's `false`
  # then the current verification error is contained in `store_context.error`.
  # and the current cert is in `store_context.current_cert`.
  #
  # If this method returns `false`, then verification stops and ruby will raise
  # an `OpenSSL::SSL::Error` with "certificate verification failed". If this
  # method returns `true`, then verification continues.
  #
  # If this method ignores a verification error, such as the cert's CRL will be
  # valid within the next 5 minutes, then this method may be called with a
  # different verification error for the same cert.
  #
  # WARNING: If `store_context.error` returns `OpenSSL::X509::V_OK`, don't
  # assume verification passed. Ruby 2.4+ implements certificate hostname
  # checking by default, and if the cert doesn't match the hostname, then the
  # error will be V_OK. Always use `preverify_ok` to determine if verification
  # succeeded or not.
  #
  # @param preverify_ok [Boolean] if `true` the current certificate in `store_context`
  #   was verified. Otherwise, check for the current error in `store_context.error`
  # @param store_context [OpenSSL::X509::StoreContext] The context holding the
  #   verification result for one certificate
  # @return [Boolean] If `true`, continue verifying the chain, even if that means
  #   ignoring the current verification error. If `false`, abort the connection.
  #
  # @api private
  def call(preverify_ok, store_context)
    return true if preverify_ok

    peer_cert = store_context.current_cert

    case store_context.error
    when OpenSSL::X509::V_OK
      # chain is from leaf to root, opposite of the order that `call` is invoked
      chain_cert = store_context.chain.first

      # ruby 2.4 doesn't compare certs based on value, so force to DER byte array
      if peer_cert && chain_cert && peer_cert.to_der == chain_cert.to_der && !OpenSSL::SSL.verify_certificate_identity(peer_cert, @hostname)
        @last_error = Puppet::SSL::CertMismatchError.new(peer_cert, @hostname)
        return false
      end

    when OpenSSL::X509::V_ERR_CRL_NOT_YET_VALID
      crl = store_context.current_crl
      if crl && crl.last_update && crl.last_update < Time.now + FIVE_MINUTES_AS_SECONDS
        Puppet.debug("Ignoring CRL not yet valid, current time #{Time.now.utc}, CRL last updated #{crl.last_update.utc}")
        return true
      end
    end

    # TRANSLATORS: `error` is an untranslated message from openssl describing why a certificate in the server's chain is invalid, and `subject` is the identity/name of the failed certificate
    @last_error = Puppet::SSL::CertVerifyError.new(
      _("certificate verify failed [%{error} for %{subject}]") %
      { error: store_context.error_string, subject: peer_cert.subject.to_utf8 },
      store_context.error, peer_cert
    )
    false
  end
end
