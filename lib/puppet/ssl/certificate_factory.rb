require 'puppet/ssl'

# This class encapsulates the logic of creating and adding extensions to X509
# certificates.
#
# @api private
module Puppet::SSL::CertificateFactory

  # Create a new X509 certificate and add any needed extensions to the cert.
  #
  # @param cert_type [Symbol] The certificate type to create, which specifies
  #   what extensions are added to the certificate.
  #   One of (:ca, :terminalsubca, :server, :ocsp, :client)
  # @param csr [Puppet::SSL::CertificateRequest] The signing request associated with
  #   the certificate being created.
  # @param issuer [OpenSSL::X509::Certificate, OpenSSL::X509::Request] An X509 CSR
  #   if this is a self signed certificate, or the X509 certificate of the CA if
  #   this is a CA signed certificate.
  # @param serial [Integer] The serial number for the given certificate, which
  #   MUST be unique for the given CA.
  # @param ttl [String] The duration of the validity for the given certificate.
  #   defaults to Puppet[:ca_ttl]
  #
  # @api public
  #
  # @return [OpenSSL::X509::Certificate]
  def self.build(cert_type, csr, issuer, serial, ttl = nil)
    # Work out if we can even build the requested type of certificate.
    build_extensions = "build_#{cert_type.to_s}_extensions"
    respond_to?(build_extensions) or
      raise ArgumentError, _("%{cert_type} is an invalid certificate type!") % { cert_type: cert_type.to_s }

    raise ArgumentError, _("Certificate TTL must be an integer") unless ttl.nil? || ttl.is_a?(Integer)

    # set up the certificate, and start building the content.
    cert = OpenSSL::X509::Certificate.new

    cert.version    = 2 # X509v3
    cert.subject    = csr.content.subject
    cert.issuer     = issuer.subject
    cert.public_key = csr.content.public_key
    cert.serial     = serial

    # Make the certificate valid as of yesterday, because so many people's
    # clocks are out of sync.  This gives one more day of validity than people
    # might expect, but is better than making every person who has a messed up
    # clock fail, and better than having every cert we generate expire a day
    # before the user expected it to when they asked for "one year".
    cert.not_before = Time.now - (60*60*24)
    cert.not_after  = Time.now + (ttl || Puppet[:ca_ttl])

    add_extensions_to(cert, csr, issuer, send(build_extensions))

    return cert
  end

  # Add X509v3 extensions to the given certificate.
  #
  # @param cert [OpenSSL::X509::Certificate] The certificate to add the
  #   extensions to.
  # @param csr [OpenSSL::X509::Request] The CSR associated with the given
  #   certificate, which may specify requested extensions for the given cert.
  #   See https://tools.ietf.org/html/rfc2985 Section 5.4.2 Extension request
  # @param issuer [OpenSSL::X509::Certificate, OpenSSL::X509::Request] An X509 CSR
  #   if this is a self signed certificate, or the X509 certificate of the CA if
  #   this is a CA signed certificate.
  # @param extensions [Hash<String, Array<String> | String>] The extensions to
  #   add to the certificate, based on the certificate type being created (CA,
  #   server, client, etc)
  #
  # @api private
  #
  # @return [void]
  def self.add_extensions_to(cert, csr, issuer, extensions)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate  = issuer.is_a?(OpenSSL::X509::Request) ? cert : issuer

    # Extract the requested extensions from the CSR.
    requested_exts = csr.request_extensions.inject({}) do |hash, re|
      hash[re["oid"]] = [re["value"], re["critical"]]
      hash
    end

    # Produce our final set of extensions.  We deliberately order these to
    # build the way we want:
    # 1. "safe" default values, like the comment, that no one cares about.
    # 2. request extensions, from the CSR
    # 3. extensions based on the type we are generating
    # 4. overrides, which we always want to have in their form
    #
    # This ordering *is* security-critical, but we want to allow the user
    # enough rope to shoot themselves in the foot, if they want to ignore our
    # advice and externally approve a CSR that sets the basicConstraints.
    #
    # Swapping the order of 2 and 3 would ensure that you couldn't slip a
    # certificate through where the CA constraint was true, though, if
    # something went wrong up there. --daniel 2011-10-11
    defaults = { "nsComment" => "Puppet Ruby/OpenSSL Internal Certificate" }

    # See https://www.openssl.org/docs/apps/x509v3_config.html
    # for information about the special meanings of 'hash', 'keyid', 'issuer'
    override = {
      "subjectKeyIdentifier"   => "hash",
      "authorityKeyIdentifier" => "keyid,issuer"
    }

    exts = [defaults, requested_exts, extensions, override].
      inject({}) {|ret, val| ret.merge(val) }

    cert.extensions = exts.map do |oid, val|
      generate_extension(ef, oid, *val)
    end
  end
  private_class_method :add_extensions_to

  # Woot! We're a CA.
  def self.build_ca_extensions
    {
      # This was accidentally omitted in the previous version of this code: an
      # effort was made to add it last, but that actually managed to avoid
      # adding it to the certificate at all.
      #
      # We have some sort of bug, which means that when we add it we get a
      # complaint that the issuer keyid can't be fetched, which breaks all
      # sorts of things in our test suite and, e.g., bootstrapping the CA.
      #
      # https://tools.ietf.org/html/rfc5280#section-4.2.1.1 says that, to be a
      # conforming CA we MAY omit the field if we are self-signed, which I
      # think gives us a pass in the specific case.
      #
      # It also notes that we MAY derive the ID from the subject and serial
      # number of the issuer, or from the key ID, and we definitely have the
      # former data, should we want to restore this...
      #
      # Anyway, preserving this bug means we don't risk breaking anything in
      # the field, even though it would be nice to have. --daniel 2011-10-11
      #
      # "authorityKeyIdentifier" => "keyid:always,issuer:always",
      "keyUsage"               => [%w{cRLSign keyCertSign}, true],
      "basicConstraints"       => ["CA:TRUE", true],
    }
  end

  # We're a terminal CA, probably not self-signed.
  def self.build_terminalsubca_extensions
    {
      "keyUsage"         => [%w{cRLSign keyCertSign}, true],
      "basicConstraints" => ["CA:TRUE,pathlen:0", true],
    }
  end

  # We're a normal server.
  def self.build_server_extensions
    {
      "keyUsage"         => [%w{digitalSignature keyEncipherment}, true],
      "extendedKeyUsage" => [%w{serverAuth clientAuth}, true],
      "basicConstraints" => ["CA:FALSE", true],
    }
  end

  # Um, no idea.
  def self.build_ocsp_extensions
    {
      "keyUsage"         => [%w{nonRepudiation digitalSignature}, true],
      "extendedKeyUsage" => [%w{serverAuth OCSPSigning}, true],
      "basicConstraints" => ["CA:FALSE", true],
    }
  end

  # Normal client.
  def self.build_client_extensions
    {
      "keyUsage"         => [%w{nonRepudiation digitalSignature keyEncipherment}, true],
      # We don't seem to use this, but that seems much more reasonable here...
      "extendedKeyUsage" => [%w{clientAuth emailProtection}, true],
      "basicConstraints" => ["CA:FALSE", true],
      "nsCertType"       => "client,email",
    }
  end

  # Generate an extension with the given OID, value, and critical state
  #
  # @param oid [String] The numeric value or short name of a given OID. X509v3
  #   extensions must be passed by short name or long name, while custom
  #   extensions may be passed by short name, long name, oid numeric OID.
  # @param ef [OpenSSL::X509::ExtensionFactory] The extension factory to use
  #   when generating the extension.
  # @param val [String, Array<String>] The extension value.
  # @param crit [true, false] Whether the given extension is critical, defaults
  #   to false.
  #
  # @return [OpenSSL::X509::Extension]
  #
  # @api private
  def self.generate_extension(ef, oid, val, crit = false)

    val = val.join(', ') unless val.is_a? String

    # Enforce the X509v3 rules about subjectAltName being critical:
    # specifically, it SHOULD NOT be critical if we have a subject, which we
    # always do. --daniel 2011-10-18
    crit = false if oid == "subjectAltName"

    if Puppet::SSL::Oids.subtree_of?('id-ce', oid) or Puppet::SSL::Oids.subtree_of?('id-pkix', oid)
      # Attempt to create a X509v3 certificate extension. Standard certificate
      # extensions may need access to the associated subject certificate and
      # issuing certificate, so must be created by the OpenSSL::X509::ExtensionFactory
      # which provides that context.
      ef.create_ext(oid, val, crit)
    else
      # This is not an X509v3 extension which means that the extension
      # factory cannot generate it. We need to generate the extension
      # manually.
      OpenSSL::X509::Extension.new(oid, OpenSSL::ASN1::UTF8String.new(val).to_der, crit)
    end
  end
  private_class_method :generate_extension
end
