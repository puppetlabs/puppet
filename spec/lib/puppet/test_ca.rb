module Puppet
  class TestCa

    CERT_VALID_FROM = Time.at(0).freeze # 1969-12-31 16:00:00 -0800
    CERT_VALID_UNTIL = (Time.now + (10 * 365 * 24 * 60 * 60)).freeze # 10 years from now

    CA_EXTENSIONS = [
      ["basicConstraints", "CA:TRUE", true],
      ["keyUsage", "keyCertSign, cRLSign", true],
      ["subjectKeyIdentifier", "hash", false],
      ["nsComment", "Puppet Server Internal Certificate", false],
      ["authorityKeyIdentifier", "keyid:always", false]
    ].freeze

    attr_reader :ca_cert, :ca_crl, :key

    @serial = 0
    def self.next_serial
      id = @serial
      @serial += 1
      id
    end

    def initialize(name = 'Test CA')
      @digest = OpenSSL::Digest::SHA256.new
      info = create_cacert(name)
      @key = info[:private_key]
      @ca_cert = info[:cert]
      @ca_crl = create_crl(@ca_cert, @key)
    end

    def create_request(name)
      key = OpenSSL::PKey::RSA.new(2048)
      csr = OpenSSL::X509::Request.new
      csr.public_key = key.public_key
      csr.subject = OpenSSL::X509::Name.new([["CN", name]])
      csr.version = 2
      csr.sign(key, @digest)
      { private_key: key, csr: csr }
    end

    def create_cert(name, issuer_cert, issuer_key, opts = {})
      key, cert = build_cert(name, issuer_cert.subject, opts)
      ef = extension_factory_for(issuer_cert, cert)
      if opts[:subject_alt_names]
        ext = ef.create_extension(["subjectAltName", opts[:subject_alt_names], false])
        cert.add_extension(ext)
      end
      if exts = opts[:extensions]
        exts.each do |e|
          cert.add_extension(OpenSSL::X509::Extension.new(*e))
        end
      end
      cert.sign(issuer_key, @digest)
      { private_key: key, cert: cert }
    end

    def create_intermediate_cert(name, issuer_cert, issuer_key)
      key, cert = build_cert(name, issuer_cert.subject)
      ef = extension_factory_for(issuer_cert, cert)
      CA_EXTENSIONS.each do |ext|
        cert.add_extension(ef.create_extension(*ext))
      end
      cert.sign(issuer_key, @digest)
      { private_key: key, cert: cert }
    end

    def create_cacert(name)
      issuer = OpenSSL::X509::Name.new([["CN", name]])
      key, cert = build_cert(name, issuer)
      ef = extension_factory_for(cert, cert)
      CA_EXTENSIONS.each do |ext|
        cert.add_extension(ef.create_extension(*ext))
      end
      cert.sign(key, @digest)
      { private_key: key, cert: cert }
    end

    def create_crl(issuer_cert, issuer_key)
      crl = OpenSSL::X509::CRL.new
      crl.version = 1
      crl.issuer = issuer_cert.subject
      ef = extension_factory_for(issuer_cert)
      crl.add_extension(
        ef.create_extension(["authorityKeyIdentifier", "keyid:always", false]))
      crl.add_extension(
        OpenSSL::X509::Extension.new("crlNumber", OpenSSL::ASN1::Integer(0)))
      crl.last_update = CERT_VALID_FROM
      crl.next_update = CERT_VALID_UNTIL
      crl.sign(issuer_key, @digest)
      crl
    end

    def sign(csr, opts = {})
      cert = OpenSSL::X509::Certificate.new
      cert.public_key = csr.public_key
      cert.subject = csr.subject
      cert.issuer = @ca_cert.subject
      cert.version = 2
      cert.serial = self.class.next_serial
      cert.not_before = CERT_VALID_FROM
      cert.not_after =  CERT_VALID_UNTIL
      ef = extension_factory_for(@ca_cert, cert)
      if opts[:subject_alt_names]
        ext = ef.create_extension(["subjectAltName", opts[:subject_alt_names], false])
        cert.add_extension(ext)
      end
      cert.sign(@key, @digest)
      Puppet::SSL::Certificate.from_instance(cert)
    end

    def revoke(cert, crl = @crl, issuer_key = @key)
      revoked = OpenSSL::X509::Revoked.new
      revoked.serial = cert.serial
      revoked.time = Time.now
      enum = OpenSSL::ASN1::Enumerated(OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE)
      ext = OpenSSL::X509::Extension.new("CRLReason", enum)
      revoked.add_extension(ext)
      crl.add_revoked(revoked)
      crl.sign(issuer_key, @digest)
    end

    def generate(name, opts)
      info = create_request(name)
      cert = sign(info[:csr], opts).content
      info.merge(cert: cert)
    end

    private

    def build_cert(name, issuer, opts = {})
      key = if opts[:key_type] == :ec
              key = OpenSSL::PKey::EC.generate('prime256v1')
            else
              key = OpenSSL::PKey::RSA.new(2048)
            end
      cert = OpenSSL::X509::Certificate.new
      cert.public_key = if key.is_a?(OpenSSL::PKey::EC)
                         # EC#public_key doesn't following the PKey API,
                         # see https://github.com/ruby/openssl/issues/29
                         point = key.public_key
                         pubkey = OpenSSL::PKey::EC.new(point.group)
                         pubkey.public_key = point
                         pubkey
                       else
                         key.public_key
                       end
      cert.subject = OpenSSL::X509::Name.new([["CN", name]])
      cert.issuer = issuer
      cert.version = 2
      cert.serial = self.class.next_serial
      cert.not_before = CERT_VALID_FROM
      cert.not_after = CERT_VALID_UNTIL
      [key, cert]
    end

    def extension_factory_for(ca, cert = nil)
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.issuer_certificate  = ca
      ef.subject_certificate = cert if cert
      ef
    end
  end
end
