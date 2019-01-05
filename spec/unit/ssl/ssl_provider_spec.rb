require 'spec_helper'

describe Puppet::SSL::SSLProvider do
  include PuppetSpec::Files

  def pem_content(name)
    File.read(my_fixture(name))
  end

  def cert(name)
    OpenSSL::X509::Certificate.new(pem_content(name))
  end

  def crl(name)
    OpenSSL::X509::CRL.new(pem_content(name))
  end

  def key(name)
    OpenSSL::PKey::RSA.new(pem_content(name))
  end

  def request(name)
    OpenSSL::X509::Request.new(pem_content(name))
  end

  let(:cacerts) { [ cert('ca.pem'), cert('intermediate.pem') ] }
  let(:crls) { [ crl('crl.pem'), crl('intermediate-crl.pem') ] }
  let(:wrong_key) { OpenSSL::PKey::RSA.new(512) }

  context 'when creating an insecure context' do
    let(:sslctx) { subject.create_insecure_context }

    it 'has an empty list of trusted certs' do
      expect(sslctx.trusted_certs).to eq([])
    end

    it 'has an empty list of crls' do
      expect(sslctx.crls).to eq([])
    end

    it 'has an empty chain' do
      expect(sslctx.chain).to eq([])
    end

    it 'has a nil private key and cert' do
      expect(sslctx.private_key).to be_nil
      expect(sslctx.client_cert).to be_nil
    end

    it 'has a NoValidator' do
      expect(subject.create_insecure_context.validator).to be_a(Puppet::SSL::Validator::NoValidator)
    end
  end

  context 'when creating an root ssl context with CA certs' do
    it 'accepts empty list of certs and crls' do
      sslctx = subject.create_root_context([], [])
      expect(sslctx.trusted_certs).to eq([])
      expect(sslctx.crls).to eq([])
    end

    it 'accepts valid root certs' do
      certs = [cert('ca.pem')]
      sslctx = subject.create_root_context(certs, [], revocation: false)
      expect(sslctx.trusted_certs).to eq(certs)
    end

    it 'accepts valid intermediate certs' do
      certs = [cert('ca.pem'), cert('intermediate.pem')]
      sslctx = subject.create_root_context(certs, [], revocation: false)
      expect(sslctx.trusted_certs).to eq(certs)
    end

    it 'raises if root cert signature is invalid', if: defined?(OpenSSL::X509::V_FLAG_CHECK_SS_SIGNATURE) do
      certs = [cert('bad-ca.pem')]
      expect {
        subject.create_root_context(certs, [], revocation: false)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate '/CN=ca-bad-signature'")
    end

    it 'raises if intermediate cert signature is invalid' do
      certs = [cert('ca.pem'), cert('bad-intermediate.pem')]
      expect {
        subject.create_root_context(certs, [], revocation: false)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate '/CN=intermediate-bad-signature'")
    end

    it "raises if intermediate cert's issuer is missing" do
      certs = [cert('ca.pem'), cert('unknown-intermediate.pem')]
      expect {
        subject.create_root_context(certs, [], revocation: false)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The issuer '/CN=unknown-ca' of certificate '/CN=unknown-int' cannot be found locally")
    end
  end

  context 'when creating an ssl context with crls' do
    it 'accepts valid CRLs' do
      certs = [cert('ca.pem')]
      crls = [crl('crl.pem')]
      sslctx = subject.create_root_context(certs, crls)
      expect(sslctx.crls).to eq(crls)
    end

    it 'accepts valid CRLs for intermediate certs' do
      certs = [cert('ca.pem'), cert('intermediate.pem')]
      crls = [crl('crl.pem'), crl('intermediate-crl.pem')]
      sslctx = subject.create_root_context(certs, crls)
      expect(sslctx.crls).to eq(crls)
    end

    it 'raises if root CRL signature is invalid', unless: Puppet::Util::Platform.jruby? do
      crl = crl('crl.pem')
      crl.sign(wrong_key, OpenSSL::Digest::SHA256.new)
      expect {
        subject.create_root_context([cert('ca.pem')], [crl])
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for CRL issued by '/CN=Test CA'")
    end

    it "does not raise if intermediate CRL's signature is invalid" do
      # The CRL for intermediate CA is only checked when verifying a
      # cert whose issuer is the intermediate CA
      crls =  [crl('crl.pem'), crl('intermediate-crl.pem')]
      crl = crls.last
      crl.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      subject.create_root_context(cacerts, crls)
    end

    it "does not raise if intermediate CRL's issuer is missing" do
      # The CRL for intermediate CA is only checked when verifying a
      # cert whose issuer is the intermediate CA
      certs = [cert('ca.pem'), cert('intermediate.pem')]
      crls = [crl('crl.pem'), crl('unknown-crl.pem')]

      subject.create_root_context(certs, crls)
    end
  end

  context 'when creating an ssl context with client certs' do
    let(:client_cert) { cert('signed.pem') }
    let(:private_key) { key('signed-key.pem') }

    it 'accepts RSA keys' do
      sslctx = subject.create_context(cacerts, crls, private_key, client_cert)
      expect(sslctx.private_key).to eq(private_key)
    end

    it 'raises if key is unsupported' do
      ec_key = OpenSSL::PKey::EC.new
      expect {
        subject.create_context(cacerts, crls, ec_key, client_cert)
      }.to raise_error(Puppet::SSL::SSLError, /Unsupported key 'OpenSSL::PKey::EC'/)
    end

    it 'resolves the client chain from leaf to root' do
      sslctx = subject.create_context(cacerts, crls, private_key, client_cert)
      expect(
        sslctx.chain.map(&:subject).map(&:to_s)
      ).to eq(['/CN=signed', '/CN=Test CA Subauthority', '/CN=Test CA'])
    end

    it 'raises if cert signature is invalid' do
      client_cert.sign(wrong_key, OpenSSL::Digest::SHA256.new)
      expect {
        subject.create_context(cacerts, crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate '/CN=signed'")
    end

    it 'raises if cert and key are mismatched' do
      expect {
        subject.create_context(cacerts, crls, wrong_key, client_cert)
      }.to raise_error(Puppet::SSL::SSLError,
                       "The certificate for '/CN=signed' does not match its private key")
    end

    it 'raises if cert has been tampered with' do
      expect {
        subject.create_context(cacerts, crls, private_key, cert('tampered-cert.pem'))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate '/CN=signed'")
    end

    it 'raises if root cert signature is invalid', if: defined?(OpenSSL::X509::V_FLAG_CHECK_SS_SIGNATURE) do
      ca = cacerts.first
      ca.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      expect {
        subject.create_context(cacerts, [], private_key, client_cert, revocation: false)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate '/CN=Test CA'")
    end

    it 'raises if intermediate CA signature is invalid' do
      int = cacerts.last
      int.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      expect {
        subject.create_context(cacerts, [], private_key, client_cert, revocation: false)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate '/CN=Test CA Subauthority'")
    end

    it 'raises if CRL signature for root CA is invalid', unless: Puppet::Util::Platform.jruby? do
      crl = crls.first
      crl.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      expect {
        subject.create_context(cacerts, crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for CRL issued by '/CN=Test CA'")
    end

    it 'raises if CRL signature for intermediate CA is invalid', unless: Puppet::Util::Platform.jruby? do
      crl = crls.last
      crl.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      expect {
        subject.create_context(cacerts, crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for CRL issued by '/CN=Test CA Subauthority'")
    end

    it 'raises if cert is revoked' do
      expect {
        subject.create_context(cacerts, crls, key('revoked-key.pem'), cert('revoked.pem'))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Certificate '/CN=revoked' is revoked")
    end

    it 'raises if intermediate issuer is missing' do
      expect {
        subject.create_context([cert('ca.pem')], crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The issuer '/CN=Test CA Subauthority' of certificate '/CN=signed' cannot be found locally")
    end

    it 'raises if root issuer is missing' do
      expect {
        subject.create_context([cert('intermediate.pem')], crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The issuer '/CN=Test CA' of certificate '/CN=Test CA Subauthority' cannot be found locally")
    end

    it 'raises if cert is not valid yet', unless: Puppet::Util::Platform.jruby? do
      client_cert.not_before = Time.now + (5 * 60 * 60)
      expect {
        subject.create_context(cacerts, crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The certificate '/CN=signed' is not yet valid, verify time is synchronized")
    end

    it 'raises if cert is expired', unless: Puppet::Util::Platform.jruby? do
      client_cert.not_after = Time.at(0)
      expect {
        subject.create_context(cacerts, crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The certificate '/CN=signed' has expired, verify time is synchronized")
    end

    it 'raises if crl is not valid yet', unless: Puppet::Util::Platform.jruby? do
      future_crls = crls
      # invalidate the CRL issued by the root
      future_crls.first.last_update = Time.now + (5 * 60 * 60)

      expect {
        subject.create_context(cacerts, future_crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by '/CN=Test CA' is not yet valid, verify time is synchronized")
    end

    it 'raises if crl is expired', unless: Puppet::Util::Platform.jruby? do
      past_crls = crls
      # invalidate the CRL issued by the root
      past_crls.first.next_update = Time.at(0)

      expect {
        subject.create_context(cacerts, past_crls, private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by '/CN=Test CA' has expired, verify time is synchronized")
    end

    it 'raises if the root CRL is missing' do
      expect {
        subject.create_context(cacerts, [crl('intermediate-crl.pem')], private_key, client_cert, revocation: :chain)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by '/CN=Test CA' is missing")
    end

    it 'raises if the intermediate CRL is missing' do
      expect {
        subject.create_context(cacerts, [crl('crl.pem')], private_key, client_cert)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by '/CN=Test CA Subauthority' is missing")
    end

    it "doesn't raise if the root CRL is missing and we're just checking the leaf" do
      crls = [crl('intermediate-crl.pem')]
      subject.create_context(cacerts, crls, private_key, client_cert, revocation: :leaf)
    end

    it "doesn't raise if the intermediate CRL is missing and revocation checking is disabled" do
      crls = [crl('crl.pem')]
      subject.create_context(cacerts, crls, private_key, client_cert, revocation: false)
    end

    it "doesn't raise if both CRLs are missing and revocation checking is disabled" do
      subject.create_context(cacerts, [], private_key, client_cert, revocation: false)
    end

    it "raises if root CA's isCA basic constraint is false", unless: Puppet::Util::Platform.jruby? || OpenSSL::OPENSSL_VERSION_NUMBER < 0x10100000 do
      certs = [cert('bad-basic-constraints.pem'), cert('intermediate.pem')]

      expect {
        subject.create_context(certs, [], private_key, client_cert, revocation: false)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Certificate '/CN=Test CA' failed verification (24): invalid CA certificate")
    end

    it "raises if intermediate CA's isCA basic constraint is false", unless: Puppet::Util::Platform.jruby? || OpenSSL::OPENSSL_VERSION_NUMBER < 0x10100000 do
      certs = [cert('ca.pem'), cert('bad-int-basic-constraints.pem')]

      expect {
        subject.create_context(certs, [], private_key, client_cert, revocation: false)
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Certificate '/CN=Test CA Subauthority' failed verification (24): invalid CA certificate")
    end

    it 'accepts CA certs in any order' do
      subject.create_context(cacerts.reverse, crls, private_key, client_cert)
    end

    it 'accepts CRLs in any order' do
      subject.create_context(cacerts, crls.reverse, private_key, client_cert)
    end
  end

  context 'when verifying requests' do
    let(:csr) { request('request.pem') }

    it 'accepts valid requests' do
      private_key = key('request-key.pem')
      expect(subject.verify_request(csr, private_key.public_key)).to eq(csr)
    end

    it "raises if the CSR was signed by a private key that doesn't match public key" do
      expect {
        subject.verify_request(csr, wrong_key.public_key)
      }.to raise_error(Puppet::SSL::SSLError,
                       "The CSR for host '/CN=pending' does not match the public key")
    end

    it "raises if the CSR was tampered with" do
      csr = request('tampered-csr.pem')
      expect {
        subject.verify_request(csr, csr.public_key)
      }.to raise_error(Puppet::SSL::SSLError,
                       "The CSR for host '/CN=signed' does not match the public key")
    end
  end
end

