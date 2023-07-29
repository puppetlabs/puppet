require 'spec_helper'
require 'puppet/application/ssl'
require 'openssl'
require 'puppet/test_ca'

describe Puppet::Application::Ssl, unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  let(:ssl) do
    app = Puppet::Application[:ssl]
    app.options[:verbose] = true
    app.setup_logs
    app
  end
  let(:name) { 'ssl-client' }

  before :all do
    @ca = Puppet::TestCa.new
    @ca_cert = @ca.ca_cert
    @crl = @ca.ca_crl
    @host = @ca.generate('ssl-client', {})
  end

  before do
    Puppet.settings.use(:main)
    Puppet[:certname] = name
    Puppet[:vardir] = tmpdir("ssl_testing")

    # Host assumes ca cert and crl are present
    File.write(Puppet[:localcacert], @ca_cert.to_pem)
    File.write(Puppet[:hostcrl], @crl.to_pem)

    # Setup our ssl client
    File.write(Puppet[:hostprivkey], @host[:private_key].to_pem)
    File.write(Puppet[:hostpubkey], @host[:private_key].public_key.to_pem)
  end

  def expects_command_to_pass(expected_output = nil)
    expect {
      ssl.run_command
    }.to output(expected_output).to_stdout
  end

  def expects_command_to_fail(message)
    expect {
      expect {
        ssl.run_command
      }.to raise_error(Puppet::Error, message)
    }.to output(/.*/).to_stdout
  end

  shared_examples_for 'an ssl action' do
    it 'downloads the CA bundle first when missing' do
      File.delete(Puppet[:localcacert])
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: 200, body: @ca.ca_cert.to_pem)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass

      expect(File.read(Puppet[:localcacert])).to eq(@ca.ca_cert.to_pem)
    end

    it 'downloads the CRL bundle first when missing' do
      File.delete(Puppet[:hostcrl])
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: 200, body: @crl.to_pem)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass

      expect(File.read(Puppet[:hostcrl])).to eq(@crl.to_pem)
    end
  end

  it 'uses the agent run mode' do
    # make sure the ssl app resolves certname, server, etc
    # the same way the agent application does
    expect(ssl.class.run_mode.name).to eq(:agent)
  end

  context 'when generating help' do
    it 'prints a message when an unknown action is specified' do
      ssl.command_line.args << 'whoops'

      expects_command_to_fail(/Unknown action 'whoops'/)
    end

    it 'prints a message requiring an action to be specified' do
      expects_command_to_fail(/An action must be specified/)
    end
  end

  context 'when submitting a CSR' do
    let(:csr_path) { Puppet[:hostcsr] }

    before do
      ssl.command_line.args << 'submit_request'
    end

    it_behaves_like 'an ssl action'

    it 'generates an RSA private key' do
      File.unlink(Puppet[:hostprivkey])

      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})
    end

    it 'generates an EC private key' do
      Puppet[:key_type] = 'ec'
      File.unlink(Puppet[:hostprivkey])

      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})
    end

    it 'registers OIDs' do
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expect(Puppet::SSL::Oids).to receive(:register_puppet_oids)
      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})
    end

    it 'submits the CSR and saves it locally' do
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      expect(Puppet::FileSystem).to be_exist(csr_path)
    end

    it 'detects when a CSR with the same public key has already been submitted' do
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass
    end

    it 'downloads the certificate when autosigning is enabled' do
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      expect(Puppet::FileSystem).to be_exist(Puppet[:hostcert])
      expect(Puppet::FileSystem).to_not be_exist(csr_path)
    end

    it 'accepts dns alt names' do
      Puppet[:dns_alt_names] = 'majortom'

      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass

      csr = Puppet::SSL::CertificateRequest.new(name)
      csr.read(csr_path)
      expect(csr.subject_alt_names).to include('DNS:majortom')
    end
  end

  context 'when generating a CSR' do
    let(:csr_path) { Puppet[:hostcsr] }
    let(:requestdir) { Puppet[:requestdir] }

    before do
      ssl.command_line.args << 'generate_request'
    end

    it_behaves_like 'an ssl action'

    it 'generates an RSA private key' do
      File.unlink(Puppet[:hostprivkey])

      expects_command_to_pass(%r{Generated certificate request for '#{name}' at #{requestdir}})
    end

    it 'generates an EC private key' do
      Puppet[:key_type] = 'ec'
      File.unlink(Puppet[:hostprivkey])

      expects_command_to_pass(%r{Generated certificate request for '#{name}' at #{requestdir}})
    end

    it 'registers OIDs' do
      expect(Puppet::SSL::Oids).to receive(:register_puppet_oids)

      expects_command_to_pass(%r{Generated certificate request for '#{name}' at #{requestdir}})
    end

    it 'saves the CSR locally' do
      expects_command_to_pass(%r{Generated certificate request for '#{name}' at #{requestdir}})

      expect(Puppet::FileSystem).to be_exist(csr_path)
    end

    it 'detects when a CSR with the same public key has already been submitted' do
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass
    end

    it 'downloads the certificate when autosigning is enabled' do
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      expect(Puppet::FileSystem).to be_exist(Puppet[:hostcert])
      expect(Puppet::FileSystem).to_not be_exist(csr_path)
    end

    it 'accepts dns alt names' do
      Puppet[:dns_alt_names] = 'majortom'

      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass

      csr = Puppet::SSL::CertificateRequest.new(name)
      csr.read(csr_path)
      expect(csr.subject_alt_names).to include('DNS:majortom')
    end
  end

  context 'when downloading a certificate' do
    before do
      ssl.command_line.args << 'download_cert'
    end

    it_behaves_like 'an ssl action'

    it 'downloads a new cert' do
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass(%r{Downloaded certificate '#{name}' with fingerprint .*})

      expect(File.read(Puppet[:hostcert])).to eq(@host[:cert].to_pem)
    end

    it 'overwrites an existing cert' do
      File.write(Puppet[:hostcert], "existing certificate")

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass(%r{Downloaded certificate '#{name}' with fingerprint .*})

      expect(File.read(Puppet[:hostcert])).to eq(@host[:cert].to_pem)
    end

    it "reports an error if the downloaded cert's public key doesn't match our private key" do
      File.write(Puppet[:hostcert], "existing cert")

      # generate a new host key, whose public key doesn't match the cert
      private_key = OpenSSL::PKey::RSA.new(512)
      File.write(Puppet[:hostprivkey], private_key.to_pem)
      File.write(Puppet[:hostpubkey], private_key.public_key.to_pem)

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_fail(
        %r{^Failed to download certificate: The certificate for 'CN=ssl-client' does not match its private key}
      )
    end

    it "prints a message if there isn't a cert to download" do
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_fail(/The certificate for '#{name}' has not yet been signed/)
    end
  end

  context 'when verifying' do
    before do
      ssl.command_line.args << 'verify'

      File.write(Puppet[:hostcert], @host[:cert].to_pem)
    end

    it 'reports if the key is missing' do
      File.delete(Puppet[:hostprivkey])

      expects_command_to_fail(/The private key is missing from/)
    end

    it 'reports if the cert is missing' do
      File.delete(Puppet[:hostcert])

      expects_command_to_fail(/The client certificate is missing from/)
    end

    it 'reports if the key and cert are mismatched' do
      # generate new keys
      private_key = OpenSSL::PKey::RSA.new(512)
      public_key = private_key.public_key
      File.write(Puppet[:hostprivkey], private_key.to_pem)
      File.write(Puppet[:hostpubkey], public_key.to_pem)

      expects_command_to_fail(%r{The certificate for 'CN=ssl-client' does not match its private key})
    end

    it 'reports if the cert verification fails' do
      # generate a new CA to force an error
      new_ca = Puppet::TestCa.new
      File.write(Puppet[:localcacert], new_ca.ca_cert.to_pem)

      # and CRL for that CA
      File.write(Puppet[:hostcrl], new_ca.ca_crl.to_pem)

      expects_command_to_fail(%r{Invalid signature for certificate 'CN=ssl-client'})
    end

    it 'reports when verification succeeds' do
      expects_command_to_pass(%r{Verified client certificate 'CN=ssl-client' fingerprint})
    end

    it 'reports when verification succeeds with a password protected private key' do
      FileUtils.cp(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'encrypted-key.pem'), Puppet[:hostprivkey])
      FileUtils.cp(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'signed.pem'), Puppet[:hostcert])

      # To verify the client cert we need the root and intermediate certs and crls.
      # We don't need to do this with `ssl-client` cert above, because it is issued
      # directly from the generated TestCa above.
      File.open(Puppet[:localcacert], 'w') do |f|
        f.write(File.read(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'ca.pem')))
        f.write(File.read(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'intermediate.pem')))
      end

      File.open(Puppet[:hostcrl], 'w') do |f|
        f.write(File.read(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'crl.pem')))
        f.write(File.read(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'intermediate-crl.pem')))
      end

      Puppet[:passfile] = file_containing('passfile', '74695716c8b6')

      expects_command_to_pass(%r{Verified client certificate 'CN=signed' fingerprint})
    end

    it 'reports if the private key password is incorrect' do
      FileUtils.cp(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'encrypted-key.pem'), Puppet[:hostprivkey])
      FileUtils.cp(File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'signed.pem'), Puppet[:hostcert])

      Puppet[:passfile] = file_containing('passfile', 'wrongpassword')

      expects_command_to_fail(/Failed to load private key for host 'ssl-client'/)
    end
  end

  context 'when cleaning' do
    before do
      ssl.command_line.args << 'clean'
    end

    it 'deletes the hostcert' do
      File.write(Puppet[:hostcert], @host[:cert].to_pem)

      expects_command_to_pass(%r{Removed certificate #{Puppet[:cert]}})
    end

    it 'deletes the private key' do
      File.write(Puppet[:hostprivkey], @host[:private_key].to_pem)

      expects_command_to_pass(%r{Removed private key #{Puppet[:hostprivkey]}})
    end

    it 'deletes the public key' do
      File.write(Puppet[:hostpubkey], @host[:private_key].public_key.to_pem)

      expects_command_to_pass(%r{Removed public key #{Puppet[:hostpubkey]}})
    end

    it 'deletes the request' do
      path = Puppet[:hostcsr]
      File.write(path, @host[:csr].to_pem)

      expects_command_to_pass(%r{Removed certificate request #{path}})
    end

    it 'deletes the passfile' do
      FileUtils.touch(Puppet[:passfile])

      expects_command_to_pass(%r{Removed private key password file #{Puppet[:passfile]}})
    end

    it 'skips files that do not exist' do
      File.delete(Puppet[:hostprivkey])

      expect {
        ssl.run_command
      }.to_not output(%r{Removed private key #{Puppet[:hostprivkey]}}).to_stdout
    end

    it "raises if we fail to retrieve server's cert that we're about to clean" do
      Puppet[:certname] = name
      Puppet[:server] = name

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_raise(Errno::ECONNREFUSED)

      expects_command_to_fail(%r{Failed to connect to the CA to determine if certificate #{name} has been cleaned})
    end

    context 'when deleting local CA' do
      before do
        ssl.command_line.args << '--localca'
        ssl.parse_options
      end

      it 'deletes the local CA cert' do
        File.write(Puppet[:localcacert], @ca_cert.to_pem)

        expects_command_to_pass(%r{Removed local CA certificate #{Puppet[:localcacert]}})
      end

      it 'deletes the local CRL' do
        File.write(Puppet[:hostcrl], @crl.to_pem)

        expects_command_to_pass(%r{Removed local CRL #{Puppet[:hostcrl]}})
      end
    end

    context 'on the puppetserver host' do
      before :each do
        Puppet[:certname] = 'puppetserver'
        Puppet[:server] = 'puppetserver'
      end

      it "prints an error when the CA is local and the CA has not cleaned its cert" do
        stub_request(:get, %r{puppet-ca/v1/certificate/puppetserver}).to_return(status: 200, body: @host[:cert].to_pem)

        expects_command_to_fail(%r{The certificate puppetserver must be cleaned from the CA first})
      end

      it "cleans the cert when the CA is local and the CA has already cleaned its cert" do
        File.write(Puppet[:hostcert], @host[:cert].to_pem)

        stub_request(:get, %r{puppet-ca/v1/certificate/puppetserver}).to_return(status: 404)

        expects_command_to_pass(%r{Removed certificate .*puppetserver.pem})
      end

      it "cleans the cert when run on a puppetserver that isn't the CA" do
        File.write(Puppet[:hostcert], @host[:cert].to_pem)

        Puppet[:ca_server] = 'caserver'

        expects_command_to_pass(%r{Removed certificate .*puppetserver.pem})
      end
    end

    context 'when cleaning a device' do
      before do
        ssl.command_line.args = ['clean', '--target', 'device.example.com']
        ssl.parse_options
      end

      it 'deletes the device certificate' do
        device_cert_path = File.join(Puppet[:devicedir], 'device.example.com', 'ssl', 'certs')
        device_cert_file = File.join(device_cert_path, 'device.example.com.pem')
        FileUtils.mkdir_p(device_cert_path)
        File.write(device_cert_file, 'device.example.com')
        expects_command_to_pass(%r{Removed certificate #{device_cert_file}})
     end
    end
  end

  context 'when bootstrapping' do
    before do
      ssl.command_line.args << 'bootstrap'
    end

    it 'registers the OIDs' do
      expect_any_instance_of(Puppet::SSL::StateMachine).to receive(:ensure_client_certificate).and_return(
        double('ssl_context')
      )
      expect(Puppet::SSL::Oids).to receive(:register_puppet_oids)
      expects_command_to_pass
    end

    it 'returns an SSLContext with the loaded CA certs, CRLs, private key and client cert' do
      expect_any_instance_of(Puppet::SSL::StateMachine).to receive(:ensure_client_certificate).and_return(
        double('ssl_context')
      )

      expects_command_to_pass
    end
  end

  context 'when showing' do
    before do
      ssl.command_line.args << 'show'
      File.write(Puppet[:hostcert], @host[:cert].to_pem)
    end

    it 'reports if the key is missing' do
      File.delete(Puppet[:hostprivkey])

      expects_command_to_fail(/The private key is missing from/)
    end

    it 'reports if the cert is missing' do
      File.delete(Puppet[:hostcert])

      expects_command_to_fail(/The client certificate is missing from/)
    end

    it 'prints certificate information' do
      expects_command_to_pass(@host[:cert].to_text)
    end
  end
end
