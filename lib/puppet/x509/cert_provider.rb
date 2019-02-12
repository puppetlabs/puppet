require 'puppet/x509'

# Class for loading and saving cert related objects.
#
# @api private
class Puppet::X509::CertProvider
  include Puppet::X509::PemStore

  # Only allow printing ascii characters, excluding /
  VALID_CERTNAME = /\A[ -.0-~]+\Z/
  CERT_DELIMITERS = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m
  CRL_DELIMITERS = /-----BEGIN X509 CRL-----.*?-----END X509 CRL-----/m

  def initialize(capath: Puppet[:localcacert],
                 crlpath: Puppet[:hostcrl],
                 privatekeydir: Puppet[:privatekeydir],
                 certdir: Puppet[:certdir],
                 requestdir: Puppet[:requestdir])
    @capath = capath
    @crlpath = crlpath
    @privatekeydir = privatekeydir
    @certdir = certdir
    @requestdir = requestdir
  end

  # Save `certs` to the configured `capath`.
  #
  # @param certs [Array<OpenSSL::X509::Certificate>] Array of CA certs to save
  # @raise [Puppet::Error] if the certs cannot be saved
  # @api private
  def save_cacerts(certs)
    save_pem(certs.map(&:to_pem).join, @capath)
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save CA certificates to '%{capath}'") % {capath: @capath}, e)
  end

  # Load CA certs from the configured `capath`.
  #
  # @return (see #load_cacerts_from_pem)
  # @raise (see #load_cacerts_from_pem)
  # @raise [Puppet::Error] if the certs cannot be loaded
  # @api private
  def load_cacerts
    pem = load_pem(@capath)
    pem ? load_cacerts_from_pem(pem) : nil
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to load CA certificates from '%{capath}'") % {capath: @capath}, e)
  end

  # Load PEM encoded CA certificates.
  #
  # @param pem [String] PEM encoded certificate(s)
  # @return [Array<OpenSSL::X509::Certificate>] Array of CA certs
  # @raise [OpenSSL::X509::CertificateError] The `pem` text does not contain a valid cert
  # @api private
  def load_cacerts_from_pem(pem)
    pem.scan(CERT_DELIMITERS).map do |text|
      OpenSSL::X509::Certificate.new(text)
    end
  end

  # Save `crls` to the configured `crlpath`.
  #
  # @param crls [Array<OpenSSL::X509::CRL>] Array of CRLs to save
  # @raise [Puppet::Error] if the CRLs cannot be saved
  # @api private
  def save_crls(crls)
    save_pem(crls.map(&:to_pem).join, @crlpath)
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save CRLs to '%{crlpath}'") % {crlpath: @crlpath}, e)
  end

  # Load CRLs from the configured `crlpath` path.
  #
  # @return (see #load_crls_from_pem)
  # @raise (see #load_crls_from_pem)
  # @raise [Puppet::Error] if the CRLs cannot be loaded
  # @api private
  def load_crls
    pem = load_pem(@crlpath)
    pem ? load_crls_from_pem(pem) : nil
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to load CRLs from '%{crlpath}'") % {crlpath: @crlpath}, e)
  end

  # Load PEM encoded CRL(s).
  #
  # @param pem [String] PEM encoded CRL(s)
  # @return [Array<OpenSSL::X509::CRL>] Array of CRLs
  # @raise [OpenSSL::X509::CRLError] The `pem` text does not contain a valid CRL
  # @api private
  def load_crls_from_pem(pem)
    pem.scan(CRL_DELIMITERS).map do |text|
      OpenSSL::X509::CRL.new(text)
    end
  end

  # Save named private key in the configured `privatekeydir`. For
  # historical reasons, names are case insensitive.
  #
  # @param name [String] The private key identity
  # @param key [OpenSSL::PKey::RSA] private key
  # @raise [Puppet::Error] if the private key cannot be saved
  # @api private
  def save_private_key(name, key)
    path = to_path(@privatekeydir, name)
    save_pem(key.to_pem, path)
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save private key for '%{name}'") % {name: name}, e)
  end

  # Load a private key from the configured `privatekeydir`. For
  # historical reasons, names are case-insensitive.
  #
  # @param name [String] The private key identity
  # @return (see #load_private_key_from_pem)
  # @raise (see #load_private_key_from_pem)
  # @raise [Puppet::Error] if the private key cannot be loaded
  # @api private
  def load_private_key(name)
    path = to_path(@privatekeydir, name)
    pem = load_pem(path)
    pem ? load_private_key_from_pem(pem) : nil
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to load private key for '%{name}'") % {name: name}, e)
  end

  # Load a PEM encoded private key.
  #
  # @param pem [String] PEM encoded private key
  # @return [OpenSSL::PKey::RSA] The private key
  # @raise [OpenSSL::PKey::RSAError] The `pem` text does not contain a valid key
  # @api private
  def load_private_key_from_pem(pem)
    # set a non-nil passphrase to ensure openssl doesn't prompt
    OpenSSL::PKey::RSA.new(pem, '')
  end

  # Save a named client cert to the configured `certdir`.
  #
  # @param name [String] The client cert identity
  # @param cert [OpenSSL::X509::Certificate] The cert to save
  # @raise [Puppet::Error] if the client cert cannot be saved
  # @api private
  def save_client_cert(name, cert)
    path = to_path(@certdir, name)
    save_pem(cert.to_pem, path)
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save client certificate for '%{name}'") % {name: name}, e)
  end

  # Load a named client cert from the configured `certdir`.
  #
  # @param name [String] The client cert identity
  # @return (see #load_request_from_pem)
  # @raise (see #load_client_cert_from_pem)
  # @raise [Puppet::Error] if the client cert cannot be loaded
  # @api private
  def load_client_cert(name)
    path = to_path(@certdir, name)
    pem = load_pem(path)
    pem ? load_client_cert_from_pem(pem) : nil
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to load client certificate for '%{name}'") % {name: name}, e)
  end

  # Load a PEM encoded certificate.
  #
  # @param pem [String] PEM encoded cert
  # @return [OpenSSL::X509::Certificate] the certificate
  # @raise [OpenSSL::X509::CertificateError] The `pem` text does not contain a valid cert
  # @api private
  def load_client_cert_from_pem(pem)
    OpenSSL::X509::Certificate.new(pem)
  end

  # Save a certificate signing request (CSR) to the configured `requestdir`.
  #
  # @param name [String] the request identity
  # @param csr [OpenSSL::X509::Request] the request
  # @raise [Puppet::Error] if the cert request cannot be saved
  # @api private
  def save_request(name, csr)
    path = to_path(@requestdir, name)
    save_pem(csr.to_pem, path)
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save certificate request for '%{name}'") % {name: name}, e)
  end

  # Load a named certificate signing request (CSR) from the configured `requestdir`.
  #
  # @param name [String] The request identity
  # @return (see #load_request_from_pem)
  # @raise (see #load_request_from_pem)
  # @raise [Puppet::Error] if the cert request cannot be saved
  # @api private
  def load_request(name)
    path = to_path(@requestdir, name)
    pem = load_pem(path)
    pem ? load_request_from_pem(pem) : nil
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to load certificate request for '%{name}'") % {name: name}, e)
  end

  # Load a PEM encoded certificate signing request (CSR).
  #
  # @param pem [String] PEM encoded request
  # @return [OpenSSL::X509::Request] the request
  # @raise [OpenSSL::X509::RequestError] The `pem` text does not contain a valid request
  # @api private
  def load_request_from_pem(pem)
    OpenSSL::X509::Request.new(pem)
  end

  private

  def to_path(base, name)
    raise _("Certname %{name} must not contain unprintable or non-ASCII characters") % { name: name.inspect } unless name =~ VALID_CERTNAME
    File.join(base, "#{name.downcase}.pem")
  end
end
