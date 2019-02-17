require 'puppet/ssl'

# Verify an SSL connection.
#
# @api private
class Puppet::SSL::Verifier

  FIVE_MINUTES_AS_SECONDS = 5 * 60

  # Create a verifier using an `ssl_context`.
  #
  # @param [Puppet::SSL::SSLContext] ssl_context containing CA certs,
  #   CRLs, etc needed to verify the server's certificate chain
  def initialize(ssl_context)
    @ssl_context = ssl_context
    @errors = []
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
    peer_cert = http.peer_cert
    host = http.address

    if peer_cert && !OpenSSL::SSL.verify_certificate_identity(peer_cert, host)
      # if `SSLSocket#post_connection_check` raises (ruby < 2.4), then peer_cert will be valid
      raise cert_mismatch_error(peer_cert, host)
    elsif !@errors.empty?
      err = @errors.first
      if err.cert && !OpenSSL::SSL.verify_certificate_identity(err.cert, host)
        # if `SSLSocket#connect` raises error, then peer_cert will be nil
        raise cert_mismatch_error(err.cert, host)
      else
        raise err
      end
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
    #puts "VERIFY ok=#{preverify_ok}, err=#{store_context.error} string=#{store_context.error_string}"

    unless preverify_ok
      peer_cert = store_context.current_cert
      err = Puppet::SSL::CertVerifyError.new(store_context.error_string, store_context.error, peer_cert)

      case store_context.error
      when OpenSSL::X509::V_ERR_CRL_NOT_YET_VALID
        crl = store_context.current_crl
        if crl && crl.last_update && crl.last_update < Time.now + FIVE_MINUTES_AS_SECONDS
          Puppet.debug("Ignoring CRL not yet valid, current time #{Time.now.utc}, CRL last updated #{crl.last_update.utc}")
          return true
        end
      end

      @errors << err
    end

    preverify_ok
  end

  private

  def cert_mismatch_error(peer_cert, host)
    valid_certnames = [peer_cert.subject.to_s.sub(/.*=/, ''),
                       *Puppet::SSL::Certificate.subject_alt_names_for(peer_cert)].uniq
    if valid_certnames.size > 1
      expected_certnames = _("expected one of %{certnames}") % { certnames: valid_certnames.join(', ') }
    else
      expected_certnames = _("expected %{certname}") % { certname: valid_certnames.first }
    end

    msg = _("Server hostname '%{host}' did not match server certificate; %{expected_certnames}") % { host: host, expected_certnames: expected_certnames }
    raise Puppet::Error, msg
  end
end
