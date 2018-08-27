module Puppet
  class TestCa

    CERT_VALID_FROM = (Time.now - (60*60*24)).freeze
    CERT_VALID_UNTIL = (Time.now + 600)

    CA_EXTENSIONS = [
      ["basicConstraints", "CA:TRUE", true],
      ["keyUsage", "keyCertSign, cRLSign", true],
      ["subjectKeyIdentifier", "hash", false],
      ["nsComment", "Puppet Server Internal Certificate", false],
      ["authorityKeyIdentifier", "keyid:always", false]
    ].freeze

    attr_reader :ca_cert, :ca_crl

    def initialize
      @digest = OpenSSL::Digest::SHA256.new
      @key = OpenSSL::PKey::RSA.new(1024)
      @ca_cert = self_signed_ca
      @ca_crl = create_crl
    end

    def sign(csr)
      cert = OpenSSL::X509::Certificate.new
      cert.public_key = csr.public_key
      cert.subject = csr.subject
      cert.issuer = @ca_cert.subject
      cert.version = 2
      cert.serial = 1
      cert.not_before = CERT_VALID_FROM
      cert.not_after =  CERT_VALID_UNTIL

      cert.sign(@key, @digest)
      Puppet::SSL::Certificate.from_instance(cert)
    end

    def revoke(cert)
      revoked = OpenSSL::X509::Revoked.new
      revoked.serial = cert.serial
      revoked.time = Time.now
      enum = OpenSSL::ASN1::Enumerated(OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE)
      ext = OpenSSL::X509::Extension.new("CRLReason", enum)
      revoked.add_extensions(ext)
      @crl.add_revoked(revoked)
    end

    private

    def self_signed_ca
      cert = OpenSSL::X509::Certificate.new

      cert.public_key = @key.public_key
      cert.subject = OpenSSL::X509::Name.new([["CN", "Test CA"]])
      cert.issuer = cert.subject
      cert.version = 2
      cert.serial = 1

      cert.not_before = CERT_VALID_FROM
      cert.not_after  = CERT_VALID_UNTIL

      ef = extension_factory_for(cert, cert)
      CA_EXTENSIONS.each do |ext|
        extension = ef.create_extension(*ext)
        cert.add_extension(extension)
      end

      cert.sign(@key, @digest)

      cert
    end

    def create_crl
      crl = OpenSSL::X509::CRL.new
      crl.version = 1
      crl.issuer = @ca_cert.subject

      ef = extension_factory_for(@ca_cert)
      crl.add_extension(
        ef.create_extension(["authorityKeyIdentifier", "keyid:always", false]))
      crl.add_extension(
        OpenSSL::X509::Extension.new("crlNumber", OpenSSL::ASN1::Integer(0)))

      crl.last_update = CERT_VALID_FROM
      crl.next_update = CERT_VALID_UNTIL
      crl.sign(@key, @digest)

      crl
    end

    def extension_factory_for(ca, cert = nil)
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.issuer_certificate  = ca
      ef.subject_certificate = cert if cert

      ef
    end
  end
end
