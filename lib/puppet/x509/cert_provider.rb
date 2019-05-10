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
  EC_HEADER = /-----BEGIN EC PRIVATE KEY-----/

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
    save_pem(certs.map(&:to_pem).join, @capath, **permissions_for_setting(:localcacert))
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save CA certificates to '%{capath}'") % {capath: @capath}, e)
  end

  # Load CA certs from the configured `capath`.
  #
  # @param required [Boolean] If true, raise if they are missing
  # @return (see #load_cacerts_from_pem)
  # @raise (see #load_cacerts_from_pem)
  # @raise [Puppet::Error] if the certs cannot be loaded
  # @api private
  def load_cacerts(required: false)
    pem = load_pem(@capath)
    if !pem && required
      raise Puppet::Error, _("The CA certificates are missing from '%{path}'") % { path: @capath }
    end
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
    # TRANSLATORS 'PEM' is an acronym and shouldn't be translated
    raise OpenSSL::X509::CertificateError, _("Failed to parse CA certificates as PEM") if pem !~ CERT_DELIMITERS

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
    save_pem(crls.map(&:to_pem).join, @crlpath, **permissions_for_setting(:hostcrl))
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save CRLs to '%{crlpath}'") % {crlpath: @crlpath}, e)
  end

  # Load CRLs from the configured `crlpath` path.
  #
  # @param required [Boolean] If true, raise if they are missing
  # @return (see #load_crls_from_pem)
  # @raise (see #load_crls_from_pem)
  # @raise [Puppet::Error] if the CRLs cannot be loaded
  # @api private
  def load_crls(required: false)
    pem = load_pem(@crlpath)
    if !pem && required
      raise Puppet::Error, _("The CRL is missing from '%{path}'") % { path: @crlpath }
    end
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
    # TRANSLATORS 'PEM' is an acronym and shouldn't be translated
    raise OpenSSL::X509::CRLError, _("Failed to parse CRLs as PEM") if pem !~ CRL_DELIMITERS

    pem.scan(CRL_DELIMITERS).map do |text|
      OpenSSL::X509::CRL.new(text)
    end
  end

  # Return the time when the CRL was last updated.
  #
  # @return [Time, nil] Time when the CRL was last updated, or nil if we don't
  #   have a CRL
  def crl_last_update
    stat = Puppet::FileSystem.stat(@crlpath)
    Time.at(stat.mtime)
  rescue Errno::ENOENT
    nil
  end

  # Set the CRL last updated time.
  #
  # @param time [Time] The last updated time
  #
  def crl_last_update=(time)
    Puppet::FileSystem.touch(@crlpath, mtime: time)
  end

  # Save named private key in the configured `privatekeydir`. For
  # historical reasons, names are case insensitive.
  #
  # @param name [String] The private key identity
  # @param key [OpenSSL::PKey::RSA] private key
  # @param password [String, nil] If non-nil, derive an encryption key
  #   from the password, and use that to encrypt the private key. If nil,
  #   save the private key unencrypted.
  # @raise [Puppet::Error] if the private key cannot be saved
  # @api private
  def save_private_key(name, key, password: nil)
    pem = if password
            cipher = OpenSSL::Cipher::AES.new(128, :CBC)
            key.export(cipher, password)
          else
            key.to_pem
          end
    path = to_path(@privatekeydir, name)
    save_pem(pem, path, **permissions_for_setting(:hostprivkey))
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save private key for '%{name}'") % {name: name}, e)
  end

  # Load a private key from the configured `privatekeydir`. For
  # historical reasons, names are case-insensitive.
  #
  # @param name [String] The private key identity
  # @param required [Boolean] If true, raise if it is missing
  # @param password [String, nil] If the private key is encrypted, decrypt
  #   it using the password. If the key is encrypted, but a password is
  #   not specified, then the key cannot be loaded.
  # @return (see #load_private_key_from_pem)
  # @raise (see #load_private_key_from_pem)
  # @raise [Puppet::Error] if the private key cannot be loaded
  # @api private
  def load_private_key(name, required: false, password: nil)
    path = to_path(@privatekeydir, name)
    pem = load_pem(path)
    if !pem && required
      raise Puppet::Error, _("The private key is missing from '%{path}'") % { path: path }
    end
    pem ? load_private_key_from_pem(pem, password: password) : nil
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to load private key for '%{name}'") % {name: name}, e)
  end

  # Load a PEM encoded private key.
  #
  # @param pem [String] PEM encoded private key
  # @param password [String, nil] If the private key is encrypted, decrypt
  #   it using the password. If the key is encrypted, but a password is
  #   not specified, then the key cannot be loaded.
  # @return [OpenSSL::PKey::RSA, OpenSSL::PKey::EC] The private key
  # @raise [OpenSSL::PKey::PKeyError] The `pem` text does not contain a valid key
  # @api private
  def load_private_key_from_pem(pem, password: nil)
    # set a non-nil password to ensure openssl doesn't prompt
    # but ruby 2.4.0 & 2.4.1 require at least 4 bytes due to
    # https://github.com/ruby/openssl/commit/f38501249f33bff7ca9d208670b8cde695ea8b7b
    # and corrected in https://github.com/ruby/openssl/commit/a896c3d1dfa090e92dec1abf8ac12843af6af721
    password ||= '    '

    if Puppet::Util::Platform.jruby?
      begin
        if pem =~ EC_HEADER
          OpenSSL::PKey::EC.new(pem, password)
        else
          OpenSSL::PKey::RSA.new(pem, password)
        end
      rescue OpenSSL::PKey::PKeyError => e
        if e.message =~ /Neither PUB key nor PRIV key/
          raise OpenSSL::PKey::PKeyError, "Could not parse PKey: no start line"
        else
          raise e
        end
      end
    else
      OpenSSL::PKey.read(pem, password)
    end
  end

  # Load the private key password.
  #
  # @return [String, nil] The private key password as a binary string or nil
  #   if there is none.
  def load_private_key_password
    Puppet::FileSystem.read(Puppet[:passfile], :encoding => Encoding::BINARY)
  rescue Errno::ENOENT
    nil
  end

  # Save a named client cert to the configured `certdir`.
  #
  # @param name [String] The client cert identity
  # @param cert [OpenSSL::X509::Certificate] The cert to save
  # @raise [Puppet::Error] if the client cert cannot be saved
  # @api private
  def save_client_cert(name, cert)
    path = to_path(@certdir, name)
    save_pem(cert.to_pem, path, **permissions_for_setting(:hostcert))
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to save client certificate for '%{name}'") % {name: name}, e)
  end

  # Load a named client cert from the configured `certdir`.
  #
  # @param name [String] The client cert identity
  # @param required [Boolean] If true, raise it is missing
  # @return (see #load_request_from_pem)
  # @raise (see #load_client_cert_from_pem)
  # @raise [Puppet::Error] if the client cert cannot be loaded
  # @api private
  def load_client_cert(name, required: false)
    path = to_path(@certdir, name)
    pem = load_pem(path)
    if !pem && required
      raise Puppet::Error, _("The client certificate is missing from '%{path}'") % { path: path }
    end
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

  # Create a certificate signing request (CSR).
  #
  # @param name [String] the request identity
  # @param private_key [OpenSSL::PKey::RSA] private key
  # @return [Puppet::X509::Request] The request
  #
  def create_request(name, private_key)
    options = {}

    if Puppet[:dns_alt_names] && Puppet[:dns_alt_names] != ''
      options[:dns_alt_names] = Puppet[:dns_alt_names]
    end

    csr_attributes = Puppet::SSL::CertificateRequestAttributes.new(Puppet[:csr_attributes])
    if csr_attributes.load
      options[:csr_attributes] = csr_attributes.custom_attributes
      options[:extension_requests] = csr_attributes.extension_requests
    end

    csr = Puppet::SSL::CertificateRequest.new(name)
    csr.generate(private_key, options)
  end

  # Save a certificate signing request (CSR) to the configured `requestdir`.
  #
  # @param name [String] the request identity
  # @param csr [OpenSSL::X509::Request] the request
  # @raise [Puppet::Error] if the cert request cannot be saved
  # @api private
  def save_request(name, csr)
    path = to_path(@requestdir, name)
    save_pem(csr.to_pem, path, **permissions_for_setting(:hostcsr))
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

  # Delete a named certificate signing request (CSR) from the configured `requestdir`.
  #
  # @param name [String] The request identity
  # @return [Boolean] true if the CSR was deleted
  def delete_request(name)
    path = to_path(@requestdir, name)
    delete_pem(path)
  rescue SystemCallError => e
    raise Puppet::Error.new(_("Failed to delete certificate request for '%{name}'") % {name: name}, e)
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

  def permissions_for_setting(name)
    setting = Puppet.settings.setting(name)
    perm = { mode: setting.mode.to_i(8) }
    perm.merge!(owner: setting.owner, group: setting.group) if Puppet.features.root? && !Puppet::Util::Platform.windows?
    perm
  end
end
