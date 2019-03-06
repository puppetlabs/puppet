require 'spec_helper'
require 'puppet/x509'

describe Puppet::X509::CertProvider do
  include PuppetSpec::Files

  def create_provider(options)
    described_class.new(options)
  end

  def as_pem_file(pem)
    path = tmpfile('cert_provider_pem')
    File.write(path, pem)
    path
  end

  let(:fixture_dir) { File.join(PuppetSpec::FIXTURE_DIR, 'ssl') }

  context 'when loading' do
    context 'cacerts' do
      it 'returns nil if it does not exist' do
        provider = create_provider(capath: '/does/not/exist')

        expect(provider.load_cacerts).to be_nil
      end

      it 'returns an array of certificates' do
        subject = OpenSSL::X509::Name.new([['CN', 'Test CA']])
        certs = create_provider(capath: File.join(fixture_dir, 'ca.pem')).load_cacerts
        expect(certs).to contain_exactly(an_object_having_attributes(subject: subject))
      end

      context 'and input is invalid' do
        it 'raises when invalid input is inside BEGIN-END block' do
          ca_path = as_pem_file(<<~END)
            -----BEGIN CERTIFICATE-----
            whoops
            -----END CERTIFICATE-----
          END

          expect {
            create_provider(capath: ca_path).load_cacerts
          }.to raise_error(OpenSSL::X509::CertificateError)
        end

        it 'raises if the input is empty' do
          expect {
            create_provider(capath: as_pem_file('')).load_cacerts
          }.to raise_error(OpenSSL::X509::CertificateError)
        end

        it 'raises if the input is malformed' do
          ca_path = as_pem_file(<<~END)
            -----BEGIN CERTIFICATE-----
            MIIBpDCCAQ2gAwIBAgIBAjANBgkqhkiG9w0BAQsFADAfMR0wGwYDVQQDDBRUZXN0
          END

          expect {
            create_provider(capath: ca_path).load_cacerts
          }.to raise_error(OpenSSL::X509::CertificateError)
        end
      end

      it 'raises if the cacerts are unreadable' do
        capath = File.join(fixture_dir, 'ca.pem')
        provider = create_provider(capath: capath)
        provider.stubs(:load_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.load_cacerts
        }.to raise_error(Puppet::Error, "Failed to load CA certificates from '#{capath}'")
      end
    end

    context 'crls' do
      it 'returns nil if it does not exist' do
        provider = create_provider(crlpath: '/does/not/exist')
        expect(provider.load_crls).to be_nil
      end

      it 'returns an array of CRLs' do
        issuer = OpenSSL::X509::Name.new([['CN', 'Test CA']])
        crls = create_provider(crlpath: File.join(fixture_dir, 'crl.pem')).load_crls
        expect(crls).to contain_exactly(an_object_having_attributes(issuer: issuer))
      end

      context 'and input is invalid' do
        it 'raises when invalid input is inside BEGIN-END block' do
          pending('jruby bug: https://github.com/jruby/jruby/issues/5619') if Puppet::Util::Platform.jruby?

          crl_path = as_pem_file(<<~END)
            -----BEGIN X509 CRL-----
            whoops
            -----END X509 CRL-----
          END

          expect {
            create_provider(crlpath: crl_path).load_crls
          }.to raise_error(OpenSSL::X509::CRLError, 'nested asn1 error')
        end

        it 'raises if the input is empty' do
          expect {
            create_provider(crlpath: as_pem_file('')).load_crls
          }.to raise_error(OpenSSL::X509::CRLError, 'Failed to parse CRLs as PEM')
        end

        it 'raises if the input is malformed' do
          crl_path = as_pem_file(<<~END)
            -----BEGIN X509 CRL-----
            MIIBCjB1AgEBMA0GCSqGSIb3DQEBCwUAMBIxEDAOBgNVBAMMB1Rlc3QgQ0EXDTcw
          END

          expect {
            create_provider(crlpath: crl_path).load_crls
          }.to raise_error(OpenSSL::X509::CRLError, 'Failed to parse CRLs as PEM')
        end
      end

      it 'raises if the CRLs are unreadable' do
        crlpath = File.join(fixture_dir, 'crl.pem')
        provider = create_provider(crlpath: crlpath)
        provider.stubs(:load_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.load_crls
        }.to raise_error(Puppet::Error, "Failed to load CRLs from '#{crlpath}'")
      end
    end
  end

  context 'when saving' do
    context 'cacerts' do
      let(:ca_path) { tmpfile('pem_cacerts') }
      let(:ca_cert) { cert_fixture('ca.pem') }

      it 'writes PEM encoded certs' do
        create_provider(capath: ca_path).save_cacerts([ca_cert])

        expect(File.read(ca_path)).to match(/\A-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----\Z/m)
      end

      it 'sets mode to 644 in PUP-9463'

      it 'raises if the CA certs are unwritable' do
        provider = create_provider(capath: ca_path)
        provider.stubs(:save_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_cacerts([ca_cert])
        }.to raise_error(Puppet::Error, "Failed to save CA certificates to '#{ca_path}'")
      end
    end

    context 'crls' do
      let(:crl_path) { tmpfile('pem_crls') }
      let(:ca_crl) { crl_fixture('crl.pem') }

      it 'writes PEM encoded CRLs' do
        create_provider(crlpath: crl_path).save_crls([ca_crl])

        expect(File.read(crl_path)).to match(/\A-----BEGIN X509 CRL-----.*?-----END X509 CRL-----\Z/m)
      end

      it 'sets mode to 644 in PUP-9463'

      it 'raises if the CRLs are unwritable' do
        provider = create_provider(crlpath: crl_path)
        provider.stubs(:save_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_crls([ca_crl])
        }.to raise_error(Puppet::Error, "Failed to save CRLs to '#{crl_path}'")
      end
    end
  end

  context 'when loading' do
    context 'private keys' do
      let(:provider) { create_provider(privatekeydir: fixture_dir) }

      it 'returns nil if it does not exist' do
        provider = create_provider(privatekeydir: '/does/not/exist')

        expect(provider.load_private_key('whatever')).to be_nil
      end

      it 'returns an RSA key' do
        expect(provider.load_private_key('signed-key')).to be_a(OpenSSL::PKey::RSA)
      end

      it 'downcases name' do
        expect(provider.load_private_key('SIGNED-KEY')).to be_a(OpenSSL::PKey::RSA)
      end

      it 'raises if name is invalid' do
        expect {
          provider.load_private_key('signed/../key')
        }.to raise_error(RuntimeError, 'Certname "signed/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'returns nil if `hostprivkey` is overridden' do
        Puppet[:certname] = 'foo'
        Puppet[:hostprivkey] = File.join(fixture_dir, "signed-key.pem")

        expect(provider.load_private_key('foo')).to be_nil
      end

      it 'raises if the private key is unreadable' do
        provider.stubs(:load_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.load_private_key('signed')
        }.to raise_error(Puppet::Error, "Failed to load private key for 'signed'")
      end

      context 'that are encrypted' do
        it 'raises without a passphrase' do
          # password is 74695716c8b6
          expect {
            provider.load_private_key('encrypted-key')
          }.to raise_error(OpenSSL::PKey::RSAError, /Neither PUB key nor PRIV key/)
        end
      end
    end

    context 'certs' do
      let(:provider) { create_provider(certdir: fixture_dir) }

      it 'returns nil if it does not exist' do
        provider = create_provider(certdir: '/does/not/exist')

        expect(provider.load_client_cert('nonexistent')).to be_nil
      end

      it 'returns a certificate' do
        cert = provider.load_client_cert('signed')
        expect(cert.subject.to_s).to eq('/CN=signed')
      end

      it 'downcases name' do
        cert = provider.load_client_cert('SIGNED')
        expect(cert.subject.to_s).to eq('/CN=signed')
      end

      it 'raises if name is invalid' do
        expect {
          provider.load_client_cert('tom/../key')
        }.to raise_error(RuntimeError, 'Certname "tom/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'returns nil if `hostcert` is overridden' do
        Puppet[:certname] = 'foo'
        Puppet[:hostcert] = File.join(fixture_dir, "signed.pem")

        expect(provider.load_client_cert('foo')).to be_nil
      end

      it 'raises if the certificate is unreadable' do
        provider.stubs(:load_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.load_client_cert('signed')
        }.to raise_error(Puppet::Error, "Failed to load client certificate for 'signed'")
      end
    end

    context 'requests' do
      let(:request) { request_fixture('request.pem') }
      let(:provider) { create_provider(requestdir: fixture_dir) }

      it 'returns nil if it does not exist' do
        expect(provider.load_request('whatever')).to be_nil
      end

      it 'returns a request' do
        expect(provider.load_request('request')).to be_a(OpenSSL::X509::Request)
      end

      it 'downcases name' do
        csr = provider.load_request('REQUEST')
        expect(csr.subject.to_s).to eq('/CN=pending')
      end

      it 'raises if name is invalid' do
        expect {
          provider.load_request('tom/../key')
        }.to raise_error(RuntimeError, 'Certname "tom/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'ignores `hostcsr`' do
        Puppet[:hostcsr] = File.join(fixture_dir, "doesnotexist.pem")

        expect(provider.load_request('request')).to be_a(OpenSSL::X509::Request)
      end

      it 'raises if the certificate is unreadable' do
        provider.stubs(:load_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.load_request('pending')
        }.to raise_error(Puppet::Error, "Failed to load certificate request for 'pending'")
      end
    end
  end

  context 'when saving' do
    let(:name) { 'tom' }

    context 'private keys' do
      let(:privatekeydir) { tmpdir('privatekeydir') }
      let(:private_key) { key_fixture('signed-key.pem') }
      let(:path) { File.join(privatekeydir, 'tom.pem') }
      let(:provider) { create_provider(privatekeydir: privatekeydir) }

      it 'writes PEM encoded private key' do
        provider.save_private_key(name, private_key)

        expect(File.read(path)).to match(/\A-----BEGIN RSA PRIVATE KEY-----.*?-----END RSA PRIVATE KEY-----\Z/m)
      end

      it 'sets mode to 640 in PUP-9463'

      it 'downcases name' do
        provider.save_private_key('TOM', private_key)

        expect(File).to be_exist(path)
      end

      it 'raises if name is invalid' do
        expect {
          provider.save_private_key('tom/../key', private_key)
        }.to raise_error(RuntimeError, 'Certname "tom/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'raises if the private key is unwritable' do
        provider.stubs(:save_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_private_key(name, private_key)
        }.to raise_error(Puppet::Error, "Failed to save private key for '#{name}'")
      end
    end

    context 'certs' do
      let(:certdir) { tmpdir('certdir') }
      let(:client_cert) { cert_fixture('signed.pem') }
      let(:path) { File.join(certdir, 'tom.pem') }
      let(:provider) { create_provider(certdir: certdir) }

      it 'writes PEM encoded cert' do
        provider.save_client_cert(name, client_cert)

        expect(File.read(path)).to match(/\A-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----\Z/m)
      end

      it 'sets mode to 644 in PUP-9463'

      it 'downcases name' do
        provider.save_client_cert('TOM', client_cert)

        expect(File).to be_exist(path)
      end

      it 'raises if name is invalid' do
        expect {
          provider.save_client_cert('tom/../key', client_cert)
        }.to raise_error(RuntimeError, 'Certname "tom/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'raises if the cert is unwritable' do
        provider.stubs(:save_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_client_cert(name, client_cert)
        }.to raise_error(Puppet::Error, "Failed to save client certificate for '#{name}'")
      end
    end

    context 'requests' do
      let(:requestdir) { tmpdir('requestdir') }
      let(:csr) { request_fixture('request.pem') }
      let(:path) { File.join(requestdir, 'tom.pem') }
      let(:provider) { create_provider(requestdir: requestdir) }

      it 'writes PEM encoded request' do
        provider.save_request(name, csr)

        expect(File.read(path)).to match(/\A-----BEGIN CERTIFICATE REQUEST-----.*?-----END CERTIFICATE REQUEST-----\Z/m)
      end

      it 'sets mode to 644 in PUP-9463'

      it 'downcases name' do
        provider.save_request('TOM', csr)

        expect(File).to be_exist(path)
      end

      it 'raises if name is invalid' do
        expect {
          provider.save_request('tom/../key', csr)
        }.to raise_error(RuntimeError, 'Certname "tom/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'raises if the request is unwritable' do
        provider.stubs(:save_pem).raises(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_request(name, csr)
        }.to raise_error(Puppet::Error, "Failed to save certificate request for '#{name}'")
      end
    end
  end
end
