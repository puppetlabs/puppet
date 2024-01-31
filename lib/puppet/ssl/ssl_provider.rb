# frozen_string_literal: true

require_relative '../../puppet/ssl'

# SSL Provider creates `SSLContext` objects that can be used to create
# secure connections.
#
# @example To load an SSLContext from an existing private key and related certs/crls:
#   ssl_context = provider.load_context
#
# @example To load an SSLContext from an existing password-protected private key and related certs/crls:
#   ssl_context = provider.load_context(password: 'opensesame')
#
# @example To create an SSLContext from in-memory certs and keys:
#   cacerts = [<OpenSSL::X509::Certificate>]
#   crls = [<OpenSSL::X509::CRL>]
#   key = <OpenSSL::X509::PKey>
#   cert = <OpenSSL::X509::Certificate>
#   ssl_context = provider.create_context(cacerts: cacerts, crls: crls, private_key: key, client_cert: cert)
#
# @example To create an SSLContext to connect to non-puppet HTTPS servers:
#   cacerts = [<OpenSSL::X509::Certificate>]
#   ssl_context = provider.create_root_context(cacerts: cacerts)
#
# @api private
class Puppet::SSL::SSLProvider
  # Create an insecure `SSLContext`. Connections made from the returned context
  # will not authenticate the server, i.e. `VERIFY_NONE`, and are vulnerable to
  # MITM. Do not call this method.
  #
  # @return [Puppet::SSL::SSLContext] A context to use to create connections
  # @api private
  def create_insecure_context
    store = create_x509_store([], [], false)

    Puppet::SSL::SSLContext.new(store: store, verify_peer: false).freeze
  end

  # Create an `SSLContext` using the trusted `cacerts` and optional `crls`.
  # Connections made from the returned context will authenticate the server,
  # i.e. `VERIFY_PEER`, but will not use a client certificate.
  #
  # The `crls` parameter must contain CRLs corresponding to each CA in `cacerts`
  # depending on the `revocation` mode. See {#create_context}.
  #
  # @param cacerts [Array<OpenSSL::X509::Certificate>] Array of trusted CA certs
  # @param crls [Array<OpenSSL::X509::CRL>] Array of CRLs
  # @param revocation [:chain, :leaf, false] revocation mode
  # @return [Puppet::SSL::SSLContext] A context to use to create connections
  # @raise (see #create_context)
  # @api private
  def create_root_context(cacerts:, crls: [], revocation: Puppet[:certificate_revocation])
    store = create_x509_store(cacerts, crls, revocation)

    Puppet::SSL::SSLContext.new(store: store, cacerts: cacerts, crls: crls, revocation: revocation).freeze
  end

  # Create an `SSLContext` using the trusted `cacerts` and any certs in OpenSSL's
  # default verify path locations. When running puppet as a gem, the location is
  # system dependent. When running puppet from puppet-agent packages, the location
  # refers to the cacerts bundle in the puppet-agent package.
  #
  # Connections made from the returned context will authenticate the server,
  # i.e. `VERIFY_PEER`, but will not use a client certificate (unless requested)
  # and will not perform revocation checking.
  #
  # @param cacerts [Array<OpenSSL::X509::Certificate>] Array of trusted CA certs
  # @param path [String, nil] A file containing additional trusted CA certs.
  # @param include_client_cert [true, false] If true, the client cert will be added to the context
  #   allowing mutual TLS authentication. The default is false. If the client cert doesn't exist
  #   then the option will be ignored.
  # @return [Puppet::SSL::SSLContext] A context to use to create connections
  # @raise (see #create_context)
  # @api private
  def create_system_context(cacerts:, path: Puppet[:ssl_trust_store], include_client_cert: false)
    store = create_x509_store(cacerts, [], false, include_system_store: true)

    if path
      stat = Puppet::FileSystem.stat(path)
      if stat
        if stat.ftype == 'file'
          # don't add empty files as ruby/openssl will raise
          if stat.size > 0
            begin
              store.add_file(path)
            rescue => e
              Puppet.err(_("Failed to add '%{path}' as a trusted CA file: %{detail}" % { path: path, detail: e.message }, e))
            end
          end
        else
          Puppet.warning(_("The 'ssl_trust_store' setting does not refer to a file and will be ignored: '%{path}'" % { path: path }))
        end
      end
    end

    if include_client_cert
      cert_provider = Puppet::X509::CertProvider.new
      private_key = cert_provider.load_private_key(Puppet[:certname], required: false)
      unless private_key
        Puppet.warning("Private key for '#{Puppet[:certname]}' does not exist")
      end

      client_cert = cert_provider.load_client_cert(Puppet[:certname], required: false)
      unless client_cert
        Puppet.warning("Client certificate for '#{Puppet[:certname]}' does not exist")
      end

      if private_key && client_cert
        client_chain = resolve_client_chain(store, client_cert, private_key)

        return Puppet::SSL::SSLContext.new(
          store: store, cacerts: cacerts, crls: [],
          private_key: private_key, client_cert: client_cert, client_chain: client_chain,
          revocation: false
        ).freeze
      end
    end

    Puppet::SSL::SSLContext.new(store: store, cacerts: cacerts, crls: [], revocation: false).freeze
  end

  # Create an `SSLContext` using the trusted `cacerts`, `crls`, `private_key`,
  # `client_cert`, and `revocation` mode. Connections made from the returned
  # context will be mutually authenticated.
  #
  # The `crls` parameter must contain CRLs corresponding to each CA in `cacerts`
  # depending on the `revocation` mode:
  #
  # * `:chain` - `crls` must contain a CRL for every CA in `cacerts`
  # * `:leaf` - `crls` must contain (at least) the CRL for the leaf CA in `cacerts`
  # * `false` - `crls` can be empty
  #
  # The `private_key` and public key from the `client_cert` must match.
  #
  # @param cacerts [Array<OpenSSL::X509::Certificate>] Array of trusted CA certs
  # @param crls [Array<OpenSSL::X509::CRL>] Array of CRLs
  # @param private_key [OpenSSL::PKey::RSA, OpenSSL::PKey::EC] client's private key
  # @param client_cert [OpenSSL::X509::Certificate] client's cert whose public
  #   key matches the `private_key`
  # @param revocation [:chain, :leaf, false] revocation mode
  # @param include_system_store [true, false] Also trust system CA
  # @return [Puppet::SSL::SSLContext] A context to use to create connections
  # @raise [Puppet::SSL::CertVerifyError] There was an issue with
  #   one of the certs or CRLs.
  # @raise [Puppet::SSL::SSLError] There was an issue with the
  #   `private_key`.
  # @api private
  def create_context(cacerts:, crls:, private_key:, client_cert:, revocation: Puppet[:certificate_revocation], include_system_store: false)
    raise ArgumentError, _("CA certs are missing") unless cacerts
    raise ArgumentError, _("CRLs are missing") unless crls
    raise ArgumentError, _("Private key is missing") unless private_key
    raise ArgumentError, _("Client cert is missing") unless client_cert

    store = create_x509_store(cacerts, crls, revocation, include_system_store: include_system_store)
    client_chain = resolve_client_chain(store, client_cert, private_key)

    Puppet::SSL::SSLContext.new(
      store: store, cacerts: cacerts, crls: crls,
      private_key: private_key, client_cert: client_cert, client_chain: client_chain,
      revocation: revocation
    ).freeze
  end

  # Load an `SSLContext` using available certs and keys. An exception is raised
  # if any component is missing or is invalid, such as a mismatched client cert
  # and private key. Connections made from the returned context will be mutually
  # authenticated.
  #
  # @param certname [String] Which cert & key to load
  # @param revocation [:chain, :leaf, false] revocation mode
  # @param password [String, nil] If the private key is encrypted, decrypt
  #   it using the password. If the key is encrypted, but a password is
  #   not specified, then the key cannot be loaded.
  # @param include_system_store [true, false] Also trust system CA
  # @return [Puppet::SSL::SSLContext] A context to use to create connections
  # @raise [Puppet::SSL::CertVerifyError] There was an issue with
  #   one of the certs or CRLs.
  # @raise [Puppet::Error] There was an issue with one of the required components.
  # @api private
  def load_context(certname: Puppet[:certname], revocation: Puppet[:certificate_revocation], password: nil, include_system_store: false)
    cert = Puppet::X509::CertProvider.new
    cacerts = cert.load_cacerts(required: true)
    crls = case revocation
           when :chain, :leaf
             cert.load_crls(required: true)
           else
             []
           end
    private_key = cert.load_private_key(certname, required: true, password: password)
    client_cert = cert.load_client_cert(certname, required: true)

    create_context(cacerts: cacerts, crls: crls,  private_key: private_key, client_cert: client_cert, revocation: revocation, include_system_store: include_system_store)
  rescue OpenSSL::PKey::PKeyError => e
    raise Puppet::SSL::SSLError.new(_("Failed to load private key for host '%{name}': %{message}") % { name: certname, message: e.message }, e)
  end

  # Verify the `csr` was signed with a private key corresponding to the
  # `public_key`. This ensures the CSR was signed by someone in possession
  # of the private key, and that it hasn't been tampered with since.
  #
  # @param csr [OpenSSL::X509::Request] certificate signing request
  # @param public_key [OpenSSL::PKey::RSA, OpenSSL::PKey::EC] public key
  # @raise [Puppet::SSL:SSLError] The private_key for the given `public_key` was
  #   not used to sign the CSR.
  # @api private
  def verify_request(csr, public_key)
    unless csr.verify(public_key)
      raise Puppet::SSL::SSLError, _("The CSR for host '%{name}' does not match the public key") % { name: subject(csr) }
    end

    csr
  end

  def print(ssl_context, alg = 'SHA256')
    if Puppet::Util::Log.sendlevel?(:debug)
      chain = ssl_context.client_chain
      # print from root to client
      chain.reverse.each_with_index do |cert, i|
        digest = Puppet::SSL::Digest.new(alg, cert.to_der)
        if i == chain.length - 1
          Puppet.debug(_("Verified client certificate '%{subject}' fingerprint %{digest}") % { subject: cert.subject.to_utf8, digest: digest })
        else
          Puppet.debug(_("Verified CA certificate '%{subject}' fingerprint %{digest}") % { subject: cert.subject.to_utf8, digest: digest })
        end
      end
      ssl_context.crls.each do |crl|
        oid_values = crl.extensions.to_h { |ext| [ext.oid, ext.value] }
        crlNumber = oid_values['crlNumber'] || 'unknown'
        authKeyId = (oid_values['authorityKeyIdentifier'] || 'unknown').chomp
        Puppet.debug("Using CRL '#{crl.issuer.to_utf8}' authorityKeyIdentifier '#{authKeyId}' crlNumber '#{crlNumber}'")
      end
    end
  end

  private

  def default_flags
    # checking the signature of the self-signed cert doesn't add any security,
    # but it's a sanity check to make sure the cert isn't corrupt. This option
    # is not available in JRuby's OpenSSL library.
    if defined?(OpenSSL::X509::V_FLAG_CHECK_SS_SIGNATURE)
      OpenSSL::X509::V_FLAG_CHECK_SS_SIGNATURE
    else
      0
    end
  end

  def create_x509_store(roots, crls, revocation, include_system_store: false)
    store = OpenSSL::X509::Store.new
    store.purpose = OpenSSL::X509::PURPOSE_ANY
    store.flags = default_flags | revocation_mode(revocation)

    roots.each { |cert| store.add_cert(cert) }
    crls.each { |crl| store.add_crl(crl) }

    store.set_default_paths if include_system_store

    store
  end

  def subject(x509)
    x509.subject.to_utf8
  end

  def issuer(x509)
    x509.issuer.to_utf8
  end

  def revocation_mode(mode)
    case mode
    when false
      0
    when :leaf
      OpenSSL::X509::V_FLAG_CRL_CHECK
    else
      # :chain is the default
      OpenSSL::X509::V_FLAG_CRL_CHECK | OpenSSL::X509::V_FLAG_CRL_CHECK_ALL
    end
  end

  def resolve_client_chain(store, client_cert, private_key)
    client_chain = verify_cert_with_store(store, client_cert)

    if !private_key.is_a?(OpenSSL::PKey::RSA) && !private_key.is_a?(OpenSSL::PKey::EC)
      raise Puppet::SSL::SSLError, _("Unsupported key '%{type}'") % { type: private_key.class.name }
    end

    unless client_cert.check_private_key(private_key)
      raise Puppet::SSL::SSLError, _("The certificate for '%{name}' does not match its private key") % { name: subject(client_cert) }
    end

    client_chain
  end

  def verify_cert_with_store(store, cert)
    # StoreContext#initialize accepts a chain argument, but it's set to [] because
    # puppet requires any intermediate CA certs needed to complete the client's
    # chain to be in the CA bundle that we downloaded from the server, and
    # they've already been added to the store. See PUP-9500.

    store_context = OpenSSL::X509::StoreContext.new(store, cert, [])
    unless store_context.verify
      current_cert = store_context.current_cert

      # If the client cert's intermediate CA is not in the CA bundle, then warn,
      # but don't error, because SSL allows the client to send an incomplete
      # chain, and have the server resolve it.
      if store_context.error == OpenSSL::X509::V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY
        Puppet.warning _("The issuer '%{issuer}' of certificate '%{subject}' cannot be found locally") % {
          issuer: issuer(current_cert), subject: subject(current_cert)
        }
      else
        raise_cert_verify_error(store_context, current_cert)
      end
    end

    # resolved chain from leaf to root
    store_context.chain
  end

  def raise_cert_verify_error(store_context, current_cert)
    message =
      case store_context.error
      when OpenSSL::X509::V_ERR_CERT_NOT_YET_VALID
        _("The certificate '%{subject}' is not yet valid, verify time is synchronized") % { subject: subject(current_cert) }
      when OpenSSL::X509::V_ERR_CERT_HAS_EXPIRED
        _("The certificate '%{subject}' has expired, verify time is synchronized") % { subject: subject(current_cert) }
      when OpenSSL::X509::V_ERR_CRL_NOT_YET_VALID
        _("The CRL issued by '%{issuer}' is not yet valid, verify time is synchronized") % { issuer: issuer(current_cert) }
      when OpenSSL::X509::V_ERR_CRL_HAS_EXPIRED
        _("The CRL issued by '%{issuer}' has expired, verify time is synchronized") % { issuer: issuer(current_cert) }
      when OpenSSL::X509::V_ERR_CERT_SIGNATURE_FAILURE
        _("Invalid signature for certificate '%{subject}'") % { subject: subject(current_cert) }
      when OpenSSL::X509::V_ERR_CRL_SIGNATURE_FAILURE
        _("Invalid signature for CRL issued by '%{issuer}'") % { issuer: issuer(current_cert) }
      when OpenSSL::X509::V_ERR_UNABLE_TO_GET_ISSUER_CERT
        _("The issuer '%{issuer}' of certificate '%{subject}' is missing") % {
          issuer: issuer(current_cert), subject: subject(current_cert)
        }
      when OpenSSL::X509::V_ERR_UNABLE_TO_GET_CRL
        _("The CRL issued by '%{issuer}' is missing") % { issuer: issuer(current_cert) }
      when OpenSSL::X509::V_ERR_CERT_REVOKED
        _("Certificate '%{subject}' is revoked") % { subject: subject(current_cert) }
      else
        # error_string is labeled ASCII-8BIT, but is encoded based on Encoding.default_external
        err_utf8 = Puppet::Util::CharacterEncoding.convert_to_utf_8(store_context.error_string)
        _("Certificate '%{subject}' failed verification (%{err}): %{err_utf8}") % {
          subject: subject(current_cert), err: store_context.error, err_utf8: err_utf8
        }
      end

    raise Puppet::SSL::CertVerifyError.new(message, store_context.error, current_cert)
  end
end
