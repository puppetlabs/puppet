require 'spec_helper'

describe Puppet::SSL::SSLProvider do
  include PuppetSpec::Files

  let(:global_cacerts) { [ cert_fixture('ca.pem'), cert_fixture('intermediate.pem') ] }
  let(:global_crls) { [ crl_fixture('crl.pem'), crl_fixture('intermediate-crl.pem') ] }
  let(:wrong_key) { OpenSSL::PKey::RSA.new(512) }

  context 'when creating an insecure context' do
    let(:sslctx) { subject.create_insecure_context }

    it 'has an empty list of trusted certs' do
      expect(sslctx.cacerts).to eq([])
    end

    it 'has an empty list of crls' do
      expect(sslctx.crls).to eq([])
    end

    it 'has an empty chain' do
      expect(sslctx.client_chain).to eq([])
    end

    it 'has a nil private key and cert' do
      expect(sslctx.private_key).to be_nil
      expect(sslctx.client_cert).to be_nil
    end

    it 'does not authenticate the server' do
      expect(sslctx.verify_peer).to eq(false)
    end

    it 'raises if the frozen context is modified' do
      expect {
        sslctx.cacerts = []
      }.to raise_error(/can't modify frozen/)
    end
  end

  context 'when creating an root ssl context with CA certs' do
    let(:config) { { cacerts: [], crls: [], revocation: false } }

    it 'accepts empty list of certs and crls' do
      sslctx = subject.create_root_context(**config)
      expect(sslctx.cacerts).to eq([])
      expect(sslctx.crls).to eq([])
    end

    it 'accepts valid root certs' do
      certs = [cert_fixture('ca.pem')]
      sslctx = subject.create_root_context(**config.merge(cacerts: certs))
      expect(sslctx.cacerts).to eq(certs)
    end

    it 'accepts valid intermediate certs' do
      certs = [cert_fixture('ca.pem'), cert_fixture('intermediate.pem')]
      sslctx = subject.create_root_context(**config.merge(cacerts: certs))
      expect(sslctx.cacerts).to eq(certs)
    end

    it 'accepts expired CA certs' do
      expired = [cert_fixture('ca.pem'), cert_fixture('intermediate.pem')]
      expired.each { |x509| x509.not_after = Time.at(0) }

      sslctx = subject.create_root_context(**config.merge(cacerts: expired))
      expect(sslctx.cacerts).to eq(expired)
    end

    it 'raises if the frozen context is modified' do
      sslctx = subject.create_root_context(**config)
      expect {
        sslctx.verify_peer = false
      }.to raise_error(/can't modify frozen/)
    end

    it 'verifies peer' do
      sslctx = subject.create_root_context(**config)
      expect(sslctx.verify_peer).to eq(true)
    end
  end

  context 'when creating a system ssl context' do
    it 'accepts empty list of CA certs' do
      sslctx = subject.create_system_context(cacerts: [])
      expect(sslctx.cacerts).to eq([])
    end

    it 'accepts valid root certs' do
      certs = [cert_fixture('ca.pem')]
      sslctx = subject.create_system_context(cacerts: certs)
      expect(sslctx.cacerts).to eq(certs)
    end

    it 'accepts valid intermediate certs' do
      certs = [cert_fixture('ca.pem'), cert_fixture('intermediate.pem')]
      sslctx = subject.create_system_context(cacerts: certs)
      expect(sslctx.cacerts).to eq(certs)
    end

    it 'accepts expired CA certs' do
      expired = [cert_fixture('ca.pem'), cert_fixture('intermediate.pem')]
      expired.each { |x509| x509.not_after = Time.at(0) }

      sslctx = subject.create_system_context(cacerts: expired)
      expect(sslctx.cacerts).to eq(expired)
    end

    it 'raises if the frozen context is modified' do
      sslctx = subject.create_system_context(cacerts: [])
      expect {
        sslctx.verify_peer = false
      }.to raise_error(/can't modify frozen/)
    end

    it 'trusts system ca store by default' do
      expect_any_instance_of(OpenSSL::X509::Store).to receive(:set_default_paths)

      subject.create_system_context(cacerts: [])
    end

    it 'trusts an external ca store' do
      path = tmpfile('system_cacerts')
      File.write(path, cert_fixture('ca.pem').to_pem)

      expect_any_instance_of(OpenSSL::X509::Store).to receive(:add_file).with(path)

      subject.create_system_context(cacerts: [], path: path)
    end

    it 'verifies peer' do
      sslctx = subject.create_system_context(cacerts: [])
      expect(sslctx.verify_peer).to eq(true)
    end

    it 'disable revocation' do
      sslctx = subject.create_system_context(cacerts: [])
      expect(sslctx.revocation).to eq(false)
    end

    it 'sets client cert and private key to nil' do
      sslctx = subject.create_system_context(cacerts: [])
      expect(sslctx.client_cert).to be_nil
      expect(sslctx.private_key).to be_nil
    end

    it 'includes the client cert and private key when requested' do
      Puppet[:hostcert] = fixtures('ssl/signed.pem')
      Puppet[:hostprivkey] = fixtures('ssl/signed-key.pem')
      sslctx = subject.create_system_context(cacerts: [], include_client_cert: true)
      expect(sslctx.client_cert).to be_an(OpenSSL::X509::Certificate)
      expect(sslctx.private_key).to be_an(OpenSSL::PKey::RSA)
    end

    it 'ignores non-existent client cert and private key when requested' do
      Puppet[:certname] = 'doesnotexist'
      sslctx = subject.create_system_context(cacerts: [], include_client_cert: true)
      expect(sslctx.client_cert).to be_nil
      expect(sslctx.private_key).to be_nil
    end

    it 'warns if the client cert does not exist' do
      Puppet[:certname] = 'missingcert'
      Puppet[:hostprivkey] = fixtures('ssl/signed-key.pem')

      expect(Puppet).to receive(:warning).with("Client certificate for 'missingcert' does not exist")
      subject.create_system_context(cacerts: [], include_client_cert: true)
    end

    it 'warns if the private key does not exist' do
      Puppet[:certname] = 'missingkey'
      Puppet[:hostcert] = fixtures('ssl/signed.pem')

      expect(Puppet).to receive(:warning).with("Private key for 'missingkey' does not exist")
      subject.create_system_context(cacerts: [], include_client_cert: true)
    end

    it 'raises if client cert and private key are mismatched' do
      Puppet[:hostcert] = fixtures('ssl/signed.pem')
      Puppet[:hostprivkey] = fixtures('ssl/127.0.0.1-key.pem')

      expect {
        subject.create_system_context(cacerts: [], include_client_cert: true)
      }.to raise_error(Puppet::SSL::SSLError,
        "The certificate for 'CN=signed' does not match its private key")
    end

    it 'trusts additional system certs' do
      path = tmpfile('system_cacerts')
      File.write(path, cert_fixture('ca.pem').to_pem)

      expect_any_instance_of(OpenSSL::X509::Store).to receive(:add_file).with(path)

      subject.create_system_context(cacerts: [], path: path)
    end

    it 'ignores empty files' do
      path = tmpfile('system_cacerts')
      FileUtils.touch(path)

      subject.create_system_context(cacerts: [], path: path)

      expect(@logs).to eq([])
    end

    it 'prints an error if it is not a file' do
      path = tmpdir('system_cacerts')

      subject.create_system_context(cacerts: [], path: path)

      expect(@logs).to include(an_object_having_attributes(level: :warning, message: /^The 'ssl_trust_store' setting does not refer to a file and will be ignored/))
    end
  end

  context 'when creating an ssl context with crls' do
    let(:config) { { cacerts: global_cacerts, crls: global_crls} }

    it 'accepts valid CRLs' do
      certs = [cert_fixture('ca.pem')]
      crls = [crl_fixture('crl.pem')]
      sslctx = subject.create_root_context(**config.merge(cacerts: certs, crls: crls))
      expect(sslctx.crls).to eq(crls)
    end

    it 'accepts valid CRLs for intermediate certs' do
      certs = [cert_fixture('ca.pem'), cert_fixture('intermediate.pem')]
      crls = [crl_fixture('crl.pem'), crl_fixture('intermediate-crl.pem')]
      sslctx = subject.create_root_context(**config.merge(cacerts: certs, crls: crls))
      expect(sslctx.crls).to eq(crls)
    end

    it 'accepts expired CRLs' do
      expired = [crl_fixture('crl.pem'), crl_fixture('intermediate-crl.pem')]
      expired.each { |x509| x509.last_update = Time.at(0) }

      sslctx = subject.create_root_context(**config.merge(crls: expired))
      expect(sslctx.crls).to eq(expired)
    end

    it 'verifies peer' do
      sslctx = subject.create_root_context(**config)
      expect(sslctx.verify_peer).to eq(true)
    end
  end

  context 'when creating an ssl context with client certs' do
    let(:client_cert) { cert_fixture('signed.pem') }
    let(:private_key) { key_fixture('signed-key.pem') }
    let(:config) { { cacerts: global_cacerts, crls: global_crls, client_cert: client_cert, private_key: private_key } }

    it 'raises if CA certs are missing' do
      expect {
        subject.create_context(**config.merge(cacerts: nil))
      }.to raise_error(ArgumentError, /CA certs are missing/)
    end

    it 'raises if CRLs are are missing' do
      expect {
        subject.create_context(**config.merge(crls: nil))
      }.to raise_error(ArgumentError, /CRLs are missing/)
    end

    it 'raises if private key is missing' do
      expect {
        subject.create_context(**config.merge(private_key: nil))
      }.to raise_error(ArgumentError, /Private key is missing/)
    end

    it 'raises if client cert is missing' do
      expect {
        subject.create_context(**config.merge(client_cert: nil))
      }.to raise_error(ArgumentError, /Client cert is missing/)
    end

    it 'accepts RSA keys' do
      sslctx = subject.create_context(**config)
      expect(sslctx.private_key).to eq(private_key)
    end

    it 'accepts EC keys' do
      ec_key = ec_key_fixture('ec-key.pem')
      ec_cert = cert_fixture('ec.pem')
      sslctx = subject.create_context(**config.merge(client_cert: ec_cert, private_key: ec_key))
      expect(sslctx.private_key).to eq(ec_key)
    end

    it 'raises if private key is unsupported' do
      dsa_key = OpenSSL::PKey::DSA.new
      expect {
        subject.create_context(**config.merge(private_key: dsa_key))
      }.to raise_error(Puppet::SSL::SSLError, /Unsupported key 'OpenSSL::PKey::DSA'/)
    end

    it 'resolves the client chain from leaf to root' do
      sslctx = subject.create_context(**config)
      expect(
        sslctx.client_chain.map(&:subject).map(&:to_utf8)
      ).to eq(['CN=signed', 'CN=Test CA Subauthority', 'CN=Test CA'])
    end

    it 'raises if client cert signature is invalid' do
      client_cert.public_key = wrong_key.public_key
      client_cert.sign(wrong_key, OpenSSL::Digest::SHA256.new)
      expect {
        subject.create_context(**config.merge(client_cert: client_cert))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate 'CN=signed'")
    end

    it 'raises if client cert and private key are mismatched' do
      expect {
        subject.create_context(**config.merge(private_key: wrong_key))
      }.to raise_error(Puppet::SSL::SSLError,
                       "The certificate for 'CN=signed' does not match its private key")
    end

    it "raises if client cert's public key has been replaced" do
      expect {
        subject.create_context(**config.merge(client_cert: cert_fixture('tampered-cert.pem')))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate 'CN=signed'")
    end

    # This option is only available in openssl 1.1
    # OpenSSL 1.1.1h no longer reports expired root CAs when using "verify".
    # This regression was fixed in 1.1.1i, so only skip this test if we're on
    # the affected version.
    # See: https://github.com/openssl/openssl/pull/13585
    if Puppet::Util::Package.versioncmp(OpenSSL::OPENSSL_LIBRARY_VERSION.split[1], '1.1.1h') != 0
      it 'raises if root cert signature is invalid', if: defined?(OpenSSL::X509::V_FLAG_CHECK_SS_SIGNATURE) do
        ca = global_cacerts.first
        ca.sign(wrong_key, OpenSSL::Digest::SHA256.new)

        expect {
          subject.create_context(**config.merge(cacerts: global_cacerts))
        }.to raise_error(Puppet::SSL::CertVerifyError,
                         "Invalid signature for certificate 'CN=Test CA'")
      end
    end

    it 'raises if intermediate CA signature is invalid' do
      int = global_cacerts.last
      int.public_key = wrong_key.public_key if Puppet::Util::Platform.jruby?
      int.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      expect {
        subject.create_context(**config.merge(cacerts: global_cacerts))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for certificate 'CN=Test CA Subauthority'")
    end

    it 'raises if CRL signature for root CA is invalid', unless: Puppet::Util::Platform.jruby? do
      crl = global_crls.first
      crl.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      expect {
        subject.create_context(**config.merge(crls: global_crls))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for CRL issued by 'CN=Test CA'")
    end

    it 'raises if CRL signature for intermediate CA is invalid', unless: Puppet::Util::Platform.jruby? do
      crl = global_crls.last
      crl.sign(wrong_key, OpenSSL::Digest::SHA256.new)

      expect {
        subject.create_context(**config.merge(crls: global_crls))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Invalid signature for CRL issued by 'CN=Test CA Subauthority'")
    end

    it 'raises if client cert is revoked' do
      expect {
        subject.create_context(**config.merge(private_key: key_fixture('revoked-key.pem'), client_cert: cert_fixture('revoked.pem')))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "Certificate 'CN=revoked' is revoked")
    end

    it 'warns if intermediate issuer is missing' do
      expect(Puppet).to receive(:warning).with("The issuer 'CN=Test CA Subauthority' of certificate 'CN=signed' cannot be found locally")

      subject.create_context(**config.merge(cacerts: [cert_fixture('ca.pem')]))
    end

    it 'raises if root issuer is missing' do
      expect {
        subject.create_context(**config.merge(cacerts: [cert_fixture('intermediate.pem')]))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The issuer 'CN=Test CA' of certificate 'CN=Test CA Subauthority' is missing")
    end

    it 'raises if cert is not valid yet', unless: Puppet::Util::Platform.jruby? do
      client_cert.not_before = Time.now + (5 * 60 * 60)
      expect {
        subject.create_context(**config.merge(client_cert: client_cert))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The certificate 'CN=signed' is not yet valid, verify time is synchronized")
    end

    it 'raises if cert is expired', unless: Puppet::Util::Platform.jruby? do
      client_cert.not_after = Time.at(0)
      expect {
        subject.create_context(**config.merge(client_cert: client_cert))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The certificate 'CN=signed' has expired, verify time is synchronized")
    end

    it 'raises if crl is not valid yet', unless: Puppet::Util::Platform.jruby? do
      future_crls = global_crls
      # invalidate the CRL issued by the root
      future_crls.first.last_update = Time.now + (5 * 60 * 60)

      expect {
        subject.create_context(**config.merge(crls: future_crls))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by 'CN=Test CA' is not yet valid, verify time is synchronized")
    end

    it 'raises if crl is expired', unless: Puppet::Util::Platform.jruby? do
      past_crls = global_crls
      # invalidate the CRL issued by the root
      past_crls.first.next_update = Time.at(0)

      expect {
        subject.create_context(**config.merge(crls: past_crls))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by 'CN=Test CA' has expired, verify time is synchronized")
    end

    it 'raises if the root CRL is missing' do
      crls = [crl_fixture('intermediate-crl.pem')]
      expect {
        subject.create_context(**config.merge(crls: crls, revocation: :chain))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by 'CN=Test CA' is missing")
    end

    it 'raises if the intermediate CRL is missing' do
      crls = [crl_fixture('crl.pem')]
      expect {
        subject.create_context(**config.merge(crls: crls))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       "The CRL issued by 'CN=Test CA Subauthority' is missing")
    end

    it "doesn't raise if the root CRL is missing and we're just checking the leaf" do
      crls = [crl_fixture('intermediate-crl.pem')]
      subject.create_context(**config.merge(crls: crls, revocation: :leaf))
    end

    it "doesn't raise if the intermediate CRL is missing and revocation checking is disabled" do
      crls = [crl_fixture('crl.pem')]
      subject.create_context(**config.merge(crls: crls, revocation: false))
    end

    it "doesn't raise if both CRLs are missing and revocation checking is disabled" do
      subject.create_context(**config.merge(crls: [], revocation: false))
    end

    # OpenSSL < 1.1 does not verify basicConstraints
    it "raises if root CA's isCA basic constraint is false", unless: Puppet::Util::Platform.jruby? || OpenSSL::OPENSSL_VERSION_NUMBER < 0x10100000 do
      certs = [cert_fixture('bad-basic-constraints.pem'), cert_fixture('intermediate.pem')]

      # openssl 3 returns 79
      # define X509_V_ERR_NO_ISSUER_PUBLIC_KEY                 24
      # define X509_V_ERR_INVALID_CA                           79
      expect {
        subject.create_context(**config.merge(cacerts: certs, crls: [], revocation: false))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       /Certificate 'CN=Test CA' failed verification \((24|79)\): invalid CA certificate/)
    end

    # OpenSSL < 1.1 does not verify basicConstraints
    it "raises if intermediate CA's isCA basic constraint is false", unless: Puppet::Util::Platform.jruby? || OpenSSL::OPENSSL_VERSION_NUMBER < 0x10100000 do
      certs = [cert_fixture('ca.pem'), cert_fixture('bad-int-basic-constraints.pem')]

      expect {
        subject.create_context(**config.merge(cacerts: certs, crls: [], revocation: false))
      }.to raise_error(Puppet::SSL::CertVerifyError,
                       /Certificate 'CN=Test CA Subauthority' failed verification \((24|79)\): invalid CA certificate/)
    end

    it 'accepts CA certs in any order' do
      sslctx = subject.create_context(**config.merge(cacerts: global_cacerts.reverse))
      # certs in ruby+openssl 1.0.x are not comparable, so compare subjects
      expect(sslctx.client_chain.map(&:subject).map(&:to_utf8)).to contain_exactly('CN=Test CA', 'CN=Test CA Subauthority', 'CN=signed')
    end

    it 'accepts CRLs in any order' do
      sslctx = subject.create_context(**config.merge(crls: global_crls.reverse))
      # certs in ruby+openssl 1.0.x are not comparable, so compare subjects
      expect(sslctx.client_chain.map(&:subject).map(&:to_utf8)).to contain_exactly('CN=Test CA', 'CN=Test CA Subauthority', 'CN=signed')
    end

    it 'raises if the frozen context is modified' do
      sslctx = subject.create_context(**config)
      expect {
        sslctx.verify_peer = false
      }.to raise_error(/can't modify frozen/)
    end

    it 'verifies peer' do
      sslctx = subject.create_context(**config)
      expect(sslctx.verify_peer).to eq(true)
    end

    it 'does not trust the system ca store by default' do
      expect_any_instance_of(OpenSSL::X509::Store).to receive(:set_default_paths).never

      subject.create_context(**config)
    end

    it 'trusts the system ca store' do
      expect_any_instance_of(OpenSSL::X509::Store).to receive(:set_default_paths)

      subject.create_context(**config.merge(include_system_store: true))
    end
  end

  context 'when loading an ssl context' do
    let(:client_cert) { cert_fixture('signed.pem') }
    let(:private_key) { key_fixture('signed-key.pem') }
    let(:doesnt_exist) { '/does/not/exist' }

    before :each do
      Puppet[:localcacert] = file_containing('global_cacerts', global_cacerts.first.to_pem)
      Puppet[:hostcrl] = file_containing('global_crls', global_crls.first.to_pem)

      Puppet[:certname] = 'signed'
      Puppet[:privatekeydir] = tmpdir('privatekeydir')
      File.write(File.join(Puppet[:privatekeydir], 'signed.pem'), private_key.to_pem)

      Puppet[:certdir] = tmpdir('privatekeydir')
      File.write(File.join(Puppet[:certdir], 'signed.pem'), client_cert.to_pem)
    end

    it 'raises if CA certs are missing' do
      Puppet[:localcacert] = doesnt_exist

      expect {
        subject.load_context
      }.to raise_error(Puppet::Error, /The CA certificates are missing from/)
    end

    it 'raises if the CRL is missing' do
      Puppet[:hostcrl] = doesnt_exist

      expect {
        subject.load_context
      }.to raise_error(Puppet::Error, /The CRL is missing from/)
    end

    it 'does not raise if the CRL is missing and revocation is disabled' do
      Puppet[:hostcrl] = doesnt_exist

      subject.load_context(revocation: false)
    end

    it 'raises if the private key is missing' do
      Puppet[:privatekeydir] = doesnt_exist

      expect {
        subject.load_context
      }.to raise_error(Puppet::Error, /The private key is missing from/)
    end

    it 'raises if the client cert is missing' do
      Puppet[:certdir] = doesnt_exist

      expect {
        subject.load_context
      }.to raise_error(Puppet::Error, /The client certificate is missing from/)
    end

    context 'loading private keys', unless: RUBY_PLATFORM == 'java' do
      it 'loads the private key and client cert' do
        ssl_context = subject.load_context

        expect(ssl_context.private_key).to be_an(OpenSSL::PKey::RSA)
        expect(ssl_context.client_cert).to be_an(OpenSSL::X509::Certificate)
      end

      it 'loads a password protected key and client cert' do
        FileUtils.cp(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'encrypted-key.pem'), File.join(Puppet[:privatekeydir], 'signed.pem'))

        ssl_context = subject.load_context(password: '74695716c8b6')

        expect(ssl_context.private_key).to be_an(OpenSSL::PKey::RSA)
        expect(ssl_context.client_cert).to be_an(OpenSSL::X509::Certificate)
      end

      it 'raises if the password is incorrect' do
        FileUtils.cp(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'encrypted-key.pem'), File.join(Puppet[:privatekeydir], 'signed.pem'))

        expect {
          subject.load_context(password: 'wrongpassword')
        }.to raise_error(Puppet::SSL::SSLError, /Failed to load private key for host 'signed': Could not parse PKey/)
      end
    end

    it 'does not trust the system ca store by default' do
      expect_any_instance_of(OpenSSL::X509::Store).to receive(:set_default_paths).never

      subject.load_context
    end

    it 'trusts the system ca store' do
      expect_any_instance_of(OpenSSL::X509::Store).to receive(:set_default_paths)

      subject.load_context(include_system_store: true)
    end
  end

  context 'when verifying requests' do
    let(:csr) { request_fixture('request.pem') }

    it 'accepts valid requests' do
      private_key = key_fixture('request-key.pem')
      expect(subject.verify_request(csr, private_key.public_key)).to eq(csr)
    end

    it "raises if the CSR was signed by a private key that doesn't match public key" do
      expect {
        subject.verify_request(csr, wrong_key.public_key)
      }.to raise_error(Puppet::SSL::SSLError,
                       "The CSR for host 'CN=pending' does not match the public key")
    end

    it "raises if the CSR was tampered with" do
      csr = request_fixture('tampered-csr.pem')
      expect {
        subject.verify_request(csr, csr.public_key)
      }.to raise_error(Puppet::SSL::SSLError,
                       "The CSR for host 'CN=signed' does not match the public key")
    end
  end
end
