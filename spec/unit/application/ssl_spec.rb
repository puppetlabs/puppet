require 'spec_helper'
require 'puppet/application/ssl'
require 'webmock/rspec'
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
    WebMock.disable_net_connect!

    Puppet.settings.use(:main)
    Puppet[:certname] = name
    Puppet[:vardir] = tmpdir("ssl_testing")

    # Host assumes ca cert and crl are present
    File.open(Puppet[:localcacert], 'w') { |f| f.write(@ca_cert.to_pem) }
    File.open(Puppet[:hostcrl], 'w') { |f| f.write(@crl.to_pem) }

    # Setup our ssl client
    File.open(Puppet[:hostprivkey], 'w') { |f| f.write(@host[:private_key].to_pem) }
    File.open(Puppet[:hostpubkey], 'w') { |f| f.write(@host[:private_key].public_key.to_pem) }
  end

  def expects_command_to_pass(expected_output = nil)
    expect {
      ssl.run_command
    }.to have_printed(expected_output)
  end

  def expects_command_to_fail(message)
    expect {
      expect {
        ssl.run_command
      }.to raise_error(Puppet::Error, message)
    }.to have_printed(/.*/) # ignore output
  end

  shared_examples_for 'an ssl action' do
    it 'downloads the CA bundle first when missing' do
      File.delete(Puppet[:localcacert])
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: 200, body: @ca.ca_cert.to_pem)
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass

      expect(File.read(Puppet[:localcacert])).to eq(@ca.ca_cert.to_pem)
    end

    it 'downloads the CRL bundle first when missing' do
      File.delete(Puppet[:hostcrl])
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: 200, body: @crl.to_pem)
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
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
    let(:csr_path) { File.join(Puppet[:requestdir], "#{name}.pem") }

    before do
      ssl.command_line.args << 'submit_request'
    end

    it_behaves_like 'an ssl action'

    it 'submits the CSR and saves it locally' do
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      expect(Puppet::FileSystem).to be_exist(csr_path)
    end

    it 'detects when a CSR with the same public key has already been submitted' do
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200, body: @host[:csr].to_pem)
      #  we skip :put
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_pass
    end

    it "warns if the local CSR doesn't match the local public key, and submits a new CSR" do
      # write out the local CSR
      File.open(csr_path, 'w') { |f| f.write(@host[:csr].to_pem) }

      # generate a new host key, whose public key doesn't match
      private_key = OpenSSL::PKey::RSA.new(512)
      public_key = private_key.public_key
      File.open(Puppet[:hostprivkey], 'w') { |f| f.write(private_key.to_pem) }
      File.open(Puppet[:hostpubkey], 'w') { |f| f.write(public_key.to_pem) }

      # expect CSR to contain the new pub key
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).with do |request|
        sent_pem = OpenSSL::X509::Request.new(request.body).public_key.to_pem
        expect(sent_pem).to eq(public_key.to_pem)
      end.to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      Puppet.stubs(:warning) # ignore unrelated warnings
      Puppet.expects(:warning).with("The local CSR does not match the agent's public key. Generating a new CSR.")
      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})
    end

    it 'downloads the certificate when autosigning is enabled' do
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass(%r{Submitted certificate request for '#{name}' to https://.*})

      expect(Puppet::FileSystem).to be_exist(Puppet[:hostcert])
    end

    it 'accepts dns alt names' do
      Puppet[:dns_alt_names] = 'majortom'

      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
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
      File.open(Puppet[:hostcert], 'w') { |f| f.write "existing certificate" }

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_pass(%r{Downloaded certificate '#{name}' with fingerprint .*})

      expect(File.read(Puppet[:hostcert])).to eq(@host[:cert].to_pem)
    end

    it "reports an error if the downloaded cert's public key doesn't match our private key" do
      File.open(Puppet[:hostcert], 'w') { |f| f.write "existing cert" }

      # generate a new host key, whose public key doesn't match the cert
      private_key = OpenSSL::PKey::RSA.new(512)
      File.open(Puppet[:hostprivkey], 'w') { |f| f.write(private_key.to_pem) }
      File.open(Puppet[:hostpubkey], 'w') { |f| f.write(private_key.public_key.to_pem) }

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_fail(
        %r{^Failed to download certificate: The certificate retrieved from the master does not match the agent's private key. Did you forget to run as root?}
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

      File.open(Puppet[:hostcert], 'w') { |f| f.write(@host[:cert].to_pem) }
    end

    it 'reports if the key is missing' do
      File.delete(Puppet[:hostprivkey])

      expects_command_to_fail(/The host's private key is missing/)
    end

    it 'reports if the cert is missing' do
      File.delete(Puppet[:hostcert])

      expects_command_to_fail(/The host's certificate is missing/)
    end

    it 'reports if the key and cert are mismatched' do
      # generate new keys
      private_key = OpenSSL::PKey::RSA.new(512)
      public_key = private_key.public_key
      File.open(Puppet[:hostprivkey], 'w') { |f| f.write(private_key.to_pem) }
      File.open(Puppet[:hostpubkey], 'w') { |f| f.write(public_key.to_pem) }

      expects_command_to_fail(/The host's key does not match the certificate/)
    end

    it 'reports if the cert verification fails' do
      # generate a new CA to force an error
      new_ca = Puppet::TestCa.new
      File.open(Puppet[:localcacert], 'w') { |f| f.write(new_ca.ca_cert.to_pem) }

      # and CRL for that CA
      File.open(Puppet[:hostcrl], 'w') { |f| f.write(new_ca.ca_crl.to_pem) }

      expects_command_to_fail(
        /Failed to verify certificate '#{name}': certificate signature failure \(7\)/
      )
    end

    it 'reports when verification succeeds' do
      OpenSSL::X509::Store.any_instance.stubs(:verify).returns(true)

      expects_command_to_pass(/Verified certificate '#{name}'/)
    end
  end

  context 'when cleaning' do
    before do
      ssl.command_line.args << 'clean'
    end

    it 'deletes the hostcert' do
      File.open(Puppet[:hostcert], 'w') { |f| f.write(@host[:cert].to_pem) }

      expects_command_to_pass(%r{Removed certificate #{Puppet[:cert]}})
    end

    it 'deletes the private key' do
      File.open(Puppet[:hostprivkey], 'w') { |f| f.write(@host[:private_key].to_pem) }

      expects_command_to_pass(%r{Removed private key #{Puppet[:hostprivkey]}})
    end

    it 'deletes the public key' do
      File.open(Puppet[:hostpubkey], 'w') { |f| f.write(@host[:private_key].public_key.to_pem) }

      expects_command_to_pass(%r{Removed public key #{Puppet[:hostpubkey]}})
    end

    it 'deletes the request' do
      File.open(Puppet[:hostcsr], 'w') { |f| f.write(@host[:csr].to_pem) }

      expects_command_to_pass(%r{Removed certificate request #{Puppet[:hostcsr]}})
    end

    it 'deletes the passfile' do
      File.open(Puppet[:passfile], 'w') { |_| }

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
        File.open(Puppet[:localcacert], 'w') { |f| f.write(@ca_cert.to_pem) }

        expects_command_to_pass(%r{Removed local CA certificate #{Puppet[:localcacert]}})
      end

      it 'deletes the local CRL' do
        File.open(Puppet[:hostcrl], 'w') { |f| f.write(@crl.to_pem) }

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
        File.open(Puppet[:hostcert], 'w') { |f| f.write(@host[:cert].to_pem) }

        stub_request(:get, %r{puppet-ca/v1/certificate/puppetserver}).to_return(status: 404)

        expects_command_to_pass(%r{Removed certificate .*puppetserver.pem})
      end

      it "cleans the cert when run on a puppetserver that isn't the CA" do
        File.open(Puppet[:hostcert], 'w') { |f| f.write(@host[:cert].to_pem) }

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
        File.open(device_cert_file, 'w') { |f| f.write('device.example.com') }
        expects_command_to_pass(%r{Removed certificate #{device_cert_file}})
     end
  end
  end
end
