require 'spec_helper'
require 'puppet/x509'

describe Puppet::X509::CertProvider do
  include PuppetSpec::Files

  def create_provider(options)
    described_class.new(**options)
  end

  def expects_public_file(path)
    if Puppet::Util::Platform.windows?
      current_sid = Puppet::Util::Windows::SID.name_to_sid(Puppet::Util::Windows::ADSI::User.current_user_name)
      sd = Puppet::Util::Windows::Security.get_security_descriptor(path)
      expect(sd.dacl).to contain_exactly(
        an_object_having_attributes(sid: Puppet::Util::Windows::SID::LocalSystem, mask: 0x1f01ff),
        an_object_having_attributes(sid: Puppet::Util::Windows::SID::BuiltinAdministrators, mask: 0x1f01ff),
        an_object_having_attributes(sid: current_sid, mask: 0x1f01ff),
        an_object_having_attributes(sid: Puppet::Util::Windows::SID::BuiltinUsers, mask: 0x120089)
      )
    else
      expect(File.stat(path).mode & 07777).to eq(0644)
    end
  end

  def expects_private_file(path)
    if Puppet::Util::Platform.windows?
      current_sid = Puppet::Util::Windows::SID.name_to_sid(Puppet::Util::Windows::ADSI::User.current_user_name)
      sd = Puppet::Util::Windows::Security.get_security_descriptor(path)
      expect(sd.dacl).to contain_exactly(
        an_object_having_attributes(sid: Puppet::Util::Windows::SID::LocalSystem, mask: 0x1f01ff),
        an_object_having_attributes(sid: Puppet::Util::Windows::SID::BuiltinAdministrators, mask: 0x1f01ff),
        an_object_having_attributes(sid: current_sid, mask: 0x1f01ff)
      )
    else
      expect(File.stat(path).mode & 07777).to eq(0640)
    end
  end

  let(:fixture_dir) { File.join(PuppetSpec::FIXTURE_DIR, 'ssl') }

  context 'when loading' do
    context 'cacerts' do
      it 'returns nil if it does not exist' do
        provider = create_provider(capath: '/does/not/exist')

        expect(provider.load_cacerts).to be_nil
      end

      it 'raises if cacerts are required' do
        provider = create_provider(capath: '/does/not/exist')

        expect {
          provider.load_cacerts(required: true)
        }.to raise_error(Puppet::Error, %r{The CA certificates are missing from '/does/not/exist'})
      end

      it 'returns an array of certificates' do
        subject = OpenSSL::X509::Name.new([['CN', 'Test CA']])
        certs = create_provider(capath: File.join(fixture_dir, 'ca.pem')).load_cacerts
        expect(certs).to contain_exactly(an_object_having_attributes(subject: subject))
      end

      context 'and input is invalid' do
        it 'raises when invalid input is inside BEGIN-END block' do
          ca_path = file_containing('invalid_ca', <<~END)
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
            create_provider(capath: file_containing('empty_ca', '')).load_cacerts
          }.to raise_error(OpenSSL::X509::CertificateError)
        end

        it 'raises if the input is malformed' do
          ca_path = file_containing('malformed_ca', <<~END)
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
        allow(provider).to receive(:load_pem).and_raise(Errno::EACCES, 'Permission denied')

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

      it 'raises if CRLs are required' do
        provider = create_provider(crlpath: '/does/not/exist')

        expect {
          provider.load_crls(required: true)
        }.to raise_error(Puppet::Error, %r{The CRL is missing from '/does/not/exist'})
      end

      it 'returns an array of CRLs' do
        issuer = OpenSSL::X509::Name.new([['CN', 'Test CA']])
        crls = create_provider(crlpath: File.join(fixture_dir, 'crl.pem')).load_crls
        expect(crls).to contain_exactly(an_object_having_attributes(issuer: issuer))
      end

      context 'and input is invalid' do
        it 'raises when invalid input is inside BEGIN-END block' do
          pending('jruby bug: https://github.com/jruby/jruby/issues/5619') if Puppet::Util::Platform.jruby?

          crl_path = file_containing('invalid_crls', <<~END)
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
            create_provider(crlpath: file_containing('empty_crl', '')).load_crls
          }.to raise_error(OpenSSL::X509::CRLError, 'Failed to parse CRLs as PEM')
        end

        it 'raises if the input is malformed' do
          crl_path = file_containing('malformed_crl', <<~END)
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
        allow(provider).to receive(:load_pem).and_raise(Errno::EACCES, 'Permission denied')

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

      it 'sets mode to 644' do
        create_provider(capath: ca_path).save_cacerts([ca_cert])

        expects_public_file(ca_path)
      end

      it 'raises if the CA certs are unwritable' do
        provider = create_provider(capath: ca_path)
        allow(provider).to receive(:save_pem).and_raise(Errno::EACCES, 'Permission denied')

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

      it 'sets mode to 644' do
        create_provider(crlpath: crl_path).save_crls([ca_crl])

        expects_public_file(crl_path)
      end

      it 'raises if the CRLs are unwritable' do
        provider = create_provider(crlpath: crl_path)
        allow(provider).to receive(:save_pem).and_raise(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_crls([ca_crl])
        }.to raise_error(Puppet::Error, "Failed to save CRLs to '#{crl_path}'")
      end
    end
  end

  context 'when loading' do
    context 'private keys' do
      let(:provider) { create_provider(privatekeydir: fixture_dir) }
      let(:password) { '74695716c8b6' }

      it 'returns nil if it does not exist' do
        provider = create_provider(privatekeydir: '/does/not/exist')

        expect(provider.load_private_key('whatever')).to be_nil
      end

      it 'raises if it is required' do
        provider = create_provider(privatekeydir: '/does/not/exist')

        expect {
          provider.load_private_key('whatever', required: true)
        }.to raise_error(Puppet::Error, %r{The private key is missing from '/does/not/exist/whatever.pem'})
      end

      it 'downcases name' do
        expect(provider.load_private_key('SIGNED-KEY')).to be_a(OpenSSL::PKey::RSA)
      end

      it 'raises if name is invalid' do
        expect {
          provider.load_private_key('signed/../key')
        }.to raise_error(RuntimeError, 'Certname "signed/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'prefers `hostprivkey` if set' do
        Puppet[:certname] = 'foo'
        Puppet[:hostprivkey] = File.join(fixture_dir, "signed-key.pem")

        expect(provider.load_private_key('foo')).to be_a(OpenSSL::PKey::RSA)
      end

      it 'raises if the private key is unreadable' do
        allow(provider).to receive(:load_pem).and_raise(Errno::EACCES, 'Permission denied')

        expect {
          provider.load_private_key('signed')
        }.to raise_error(Puppet::Error, "Failed to load private key for 'signed'")
      end

      context 'using RSA' do
        it 'returns an RSA key' do
          expect(provider.load_private_key('signed-key')).to be_a(OpenSSL::PKey::RSA)
        end

        it 'decrypts an RSA key using the password' do
          rsa = provider.load_private_key('encrypted-key', password: password)
          expect(rsa).to be_a(OpenSSL::PKey::RSA)
        end

        it 'raises without a password' do
          # password is 74695716c8b6
          expect {
            provider.load_private_key('encrypted-key')
          }.to raise_error(OpenSSL::PKey::PKeyError, /Could not parse PKey: no start line/)
        end

        it 'decrypts an RSA key previously saved using 3DES' do
          key = key_fixture('signed-key.pem')
          cipher = OpenSSL::Cipher::DES.new(:EDE3, :CBC)
          privatekeydir = dir_containing('private_keys', {'oldkey.pem' => key.export(cipher, password)})
          provider = create_provider(privatekeydir: privatekeydir)

          expect(provider.load_private_key('oldkey', password: password).to_der).to eq(key.to_der)
        end
      end

      context 'using EC' do
        it 'returns an EC key' do
          expect(provider.load_private_key('ec-key')).to be_a(OpenSSL::PKey::EC)
        end

        it 'decrypts an EC key using the password' do
          ec = provider.load_private_key('encrypted-ec-key', password: password)
          expect(ec).to be_a(OpenSSL::PKey::EC)
        end

        it 'raises without a password' do
          # password is 74695716c8b6
          expect {
            provider.load_private_key('encrypted-ec-key')
          }.to raise_error(OpenSSL::PKey::PKeyError, /(unknown|invalid) curve name|Could not parse PKey: no start line/)
        end
      end
    end

    context 'certs' do
      let(:provider) { create_provider(certdir: fixture_dir) }

      it 'returns nil if it does not exist' do
        provider = create_provider(certdir: '/does/not/exist')

        expect(provider.load_client_cert('nonexistent')).to be_nil
      end

      it 'raises if it is required' do
        provider = create_provider(certdir: '/does/not/exist')

        expect {
          provider.load_client_cert('nonexistent', required: true)
        }.to raise_error(Puppet::Error, %r{The client certificate is missing from '/does/not/exist/nonexistent.pem'})
      end

      it 'returns a certificate' do
        cert = provider.load_client_cert('signed')
        expect(cert.subject.to_utf8).to eq('CN=signed')
      end

      it 'downcases name' do
        cert = provider.load_client_cert('SIGNED')
        expect(cert.subject.to_utf8).to eq('CN=signed')
      end

      it 'raises if name is invalid' do
        expect {
          provider.load_client_cert('tom/../key')
        }.to raise_error(RuntimeError, 'Certname "tom/../key" must not contain unprintable or non-ASCII characters')
      end

      it 'prefers `hostcert` if set' do
        Puppet[:certname] = 'foo'
        Puppet[:hostcert] = File.join(fixture_dir, "signed.pem")

        expect(provider.load_client_cert('foo')).to be_a(OpenSSL::X509::Certificate)
      end

      it 'raises if the certificate is unreadable' do
        allow(provider).to receive(:load_pem).and_raise(Errno::EACCES, 'Permission denied')

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
        expect(csr.subject.to_utf8).to eq('CN=pending')
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
        allow(provider).to receive(:load_pem).and_raise(Errno::EACCES, 'Permission denied')

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

      it 'encrypts the private key using AES128-CBC' do
        provider.save_private_key(name, private_key, password: Random.new.bytes(8))

        expect(File.read(path)).to match(/Proc-Type: 4,ENCRYPTED.*DEK-Info: AES-128-CBC/m)
      end

      it 'sets mode to 640' do
        provider.save_private_key(name, private_key)

        expects_private_file(path)
      end

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
        allow(provider).to receive(:save_pem).and_raise(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_private_key(name, private_key)
        }.to raise_error(Puppet::Error, "Failed to save private key for '#{name}'")
      end

      it 'prefers `hostprivkey` if set' do
        overridden_path = tmpfile('hostprivkey')
        Puppet[:hostprivkey] = overridden_path

        provider.save_private_key(name, private_key)

        expect(File).to_not exist(path)
        expect(File).to exist(overridden_path)
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

      it 'sets mode to 644' do
        provider.save_client_cert(name, client_cert)

        expects_public_file(path)
      end

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
        allow(provider).to receive(:save_pem).and_raise(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_client_cert(name, client_cert)
        }.to raise_error(Puppet::Error, "Failed to save client certificate for '#{name}'")
      end

      it 'prefers `hostcert` if set' do
        overridden_path = tmpfile('hostcert')
        Puppet[:hostcert] = overridden_path

        provider.save_client_cert(name, client_cert)

        expect(File).to_not exist(path)
        expect(File).to exist(overridden_path)
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

      it 'sets mode to 644' do
        provider.save_request(name, csr)

        expects_public_file(path)
      end

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
        allow(provider).to receive(:save_pem).and_raise(Errno::EACCES, 'Permission denied')

        expect {
          provider.save_request(name, csr)
        }.to raise_error(Puppet::Error, "Failed to save certificate request for '#{name}'")
      end
    end
  end

  context 'when deleting' do
    context 'requests' do
      let(:name) { 'jerry' }
      let(:requestdir) { tmpdir('cert_provider') }
      let(:provider) { create_provider(requestdir: requestdir) }

      it 'returns true if request was deleted' do
        path = File.join(requestdir, "#{name}.pem")
        File.write(path, "PEM")

        expect(provider.delete_request(name)).to eq(true)
        expect(File).not_to be_exist(path)
      end

      it 'returns false if the request is non-existent' do
        path = File.join(requestdir, "#{name}.pem")

        expect(provider.delete_request(name)).to eq(false)
        expect(File).to_not be_exist(path)
      end

      it 'raises if the file is undeletable' do
        allow(provider).to receive(:delete_pem).and_raise(Errno::EACCES, 'Permission denied')

        expect {
          provider.delete_request(name)
        }.to raise_error(Puppet::Error, "Failed to delete certificate request for '#{name}'")
      end
    end
  end

  context 'CRL last update time' do
    let(:crl_path) { tmpfile('pem_crls') }

    it 'returns nil if the CRL does not exist' do
      provider = create_provider(crlpath: '/does/not/exist')

      expect(provider.crl_last_update).to be_nil
    end

    it 'returns the last update time' do
      time = Time.now - 30
      Puppet::FileSystem.touch(crl_path, mtime: time)
      provider = create_provider(crlpath: crl_path)

      expect(provider.crl_last_update).to be_within(1).of(time)
    end

    it 'sets the last update time' do
      time = Time.now - 30
      provider = create_provider(crlpath: crl_path)
      provider.crl_last_update = time

      expect(Puppet::FileSystem.stat(crl_path).mtime).to be_within(1).of(time)
    end
  end
end
