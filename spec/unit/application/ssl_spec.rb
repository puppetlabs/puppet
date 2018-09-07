require 'spec_helper'
require 'puppet/application/ssl'
require 'webmock/rspec'
require 'openssl'

describe Puppet::Application::Ssl do
  let(:ssl) { Puppet::Application[:ssl] }
  let(:name) { 'ssl-client' }

  def generate_cert(name, issuer = nil, issuer_key = nil)
    # generate CA key pair
    private_key = OpenSSL::PKey::RSA.new(512)
    public_key = private_key.public_key

    # generate CSR
    csr = OpenSSL::X509::Request.new
    csr.version = 0
    csr.subject = OpenSSL::X509::Name.new([["CN", name]])
    csr.public_key = public_key
    csr.sign(private_key, OpenSSL::Digest::SHA256.new)

    # is it self-signed?
    issuer ||= csr.subject
    issuer_key ||= private_key

    # issue cert
    cert = OpenSSL::X509::Certificate.new
    cert.version    = 2 # X509v3
    cert.subject    = csr.subject
    cert.issuer     = issuer
    cert.public_key = csr.public_key
    cert.serial     = 1
    cert.not_before = Time.now - (60*60*24)
    cert.not_after  = Time.now + (60*60*24)
    cert.sign(issuer_key, OpenSSL::Digest::SHA256.new)

    {:private_key => private_key, :csr => csr, :cert => cert}
  end

  def generate_crl(name, issuer, issuer_key)
    crl = OpenSSL::X509::CRL.new
    crl.version = 1
    crl.issuer = issuer
    crl.last_update = Time.now - (60*60*24)
    crl.next_update =  Time.now + (60*60*24)
    crl.extensions = [OpenSSL::X509::Extension.new('crlNumber', OpenSSL::ASN1::Integer(0))]
    crl.sign(issuer_key, OpenSSL::Digest::SHA256.new)

    crl
  end

  before :all do
    @ca = generate_cert('ca')
    @crl = generate_crl('ca', @ca[:cert].subject, @ca[:private_key])
    @host = generate_cert('ssl-client', @ca[:cert].subject, @ca[:private_key])
  end

  before do
    WebMock.disable_net_connect!

    Puppet.settings.use(:main)
    Puppet[:certname] = name

    # Host assumes ca cert and crl are present
    File.open(Puppet[:localcacert], 'w') { |f| f.write(@ca[:cert].to_pem) }
    File.open(Puppet[:hostcrl], 'w') { |f| f.write(@crl.to_pem) }

    # Setup our ssl client
    File.open(Puppet[:hostprivkey], 'w') { |f| f.write(@host[:private_key].to_pem) }
    File.open(Puppet[:hostpubkey], 'w') { |f| f.write(@host[:private_key].public_key.to_pem) }
  end

  def expects_command_to_output(expected_message = nil, code = 0)
    expect {
      expect {
        ssl.run_command
      }.to exit_with(code)
    }.to output(expected_message).to_stdout
  end

  shared_examples_for 'an ssl action' do
    it 'downloads the CA bundle first when missing' do
      File.delete(Puppet[:localcacert])
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: 200, body: @ca[:cert].to_pem)
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_output

      expect(File.read(Puppet[:localcacert])).to eq(@ca[:cert].to_pem)
    end

    it 'downloads the CRL bundle first when missing' do
      File.delete(Puppet[:hostcrl])
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: 200, body: @crl.to_pem)
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_output

      expect(File.read(Puppet[:hostcrl])).to eq(@crl.to_pem)
    end
  end

  context 'when generating help' do
    it 'prints usage when no arguments are specified' do
      ssl.command_line.args << 'whoops'

      expects_command_to_output(/Unknown action 'whoops'/, 1)
    end

    it 'rejects unknown actions' do
      expects_command_to_output(/^puppet-ssl.*SYNOPSIS/m, 1)
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

      expects_command_to_output(%r{Submitted certificate request for '#{name}' to https://.*}, 0)

      expect(Puppet::FileSystem).to be_exist(csr_path)
    end

    it 'detects when a CSR with the same public key has already been submitted' do
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_output(%r{Submitted certificate request for '#{name}' to https://.*}, 0)

      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200, body: @host[:csr].to_pem)
      #  we skip :put
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_output
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
      expects_command_to_output(%r{Submitted certificate request for '#{name}' to https://.*}, 0)
    end

    it 'downloads the certificate when autosigning is enabled' do
      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_output(%r{Submitted certificate request for '#{name}' to https://.*}, 0)

      expect(Puppet::FileSystem).to be_exist(Puppet[:hostcert])
    end

    it 'accepts dns alt names' do
      Puppet[:dns_alt_names] = 'majortom'

      stub_request(:get, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 404)
      stub_request(:put, %r{puppet-ca/v1/certificate_request/#{name}}).to_return(status: 200)
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_output

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

      expects_command_to_output(%r{Downloaded certificate '#{name}' with fingerprint .*})

      expect(File.read(Puppet[:hostcert])).to eq(@host[:cert].to_pem)
    end

    it 'overwrites an existing cert' do
      File.open(Puppet[:hostcert], 'w') { |f| f.write "existing certificate" }

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_output(%r{Downloaded certificate '#{name}' with fingerprint .*})

      expect(File.read(Puppet[:hostcert])).to eq(@host[:cert].to_pem)
    end

    it "reports an error if the downloaded cert's public key doesn't match our private key" do
      File.open(Puppet[:hostcert], 'w') { |f| f.write "existing cert" }

      # generate a new host key, whose public key doesn't match the cert
      private_key = OpenSSL::PKey::RSA.new(512)
      File.open(Puppet[:hostprivkey], 'w') { |f| f.write(private_key.to_pem) }
      File.open(Puppet[:hostpubkey], 'w') { |f| f.write(private_key.public_key.to_pem) }

      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 200, body: @host[:cert].to_pem)

      expects_command_to_output(%r{^Failed to download certificate: The certificate retrieved from the master does not match the agent's private key. Did you forget to run as root?}, 1)
    end

    it "prints a message if there isn't a cert to download" do
      stub_request(:get, %r{puppet-ca/v1/certificate/#{name}}).to_return(status: 404)

      expects_command_to_output(/No certificate for '#{name}' on CA/)
    end
  end

  context 'when verifying' do
    before do
      ssl.command_line.args << 'verify'

      File.open(Puppet[:hostcert], 'w') { |f| f.write(@host[:cert].to_pem) }
    end

    it 'reports if the key is missing' do
      File.delete(Puppet[:hostprivkey])

      expects_command_to_output(/The host's private key is missing/, 1)
    end

    it 'reports if the cert is missing' do
      File.delete(Puppet[:hostcert])

      expects_command_to_output(/The host's certificate is missing/, 1)
    end

    it 'reports if the key and cert are mismatched' do
      # generate new keys
      private_key = OpenSSL::PKey::RSA.new(512)
      public_key = private_key.public_key
      File.open(Puppet[:hostprivkey], 'w') { |f| f.write(private_key.to_pem) }
      File.open(Puppet[:hostpubkey], 'w') { |f| f.write(public_key.to_pem) }

      expects_command_to_output(/The host's key does not match the certificate/, 1)
    end

    it 'reports if the cert verification fails' do
      # generate a new CA to force an error
      ca = generate_cert('ca')
      File.open(Puppet[:localcacert], 'w') { |f| f.write(ca[:cert].to_pem) }

      # and CRL for that CA
      crl = generate_crl('ca', ca[:cert].subject, ca[:private_key])
      File.open(Puppet[:hostcrl], 'w') { |f| f.write(crl.to_pem) }

      expects_command_to_output(/Failed to verify certificate '#{name}': certificate signature failure \(7\)/, 1)
    end

    it 'reports when verification succeeds' do
      OpenSSL::X509::Store.any_instance.stubs(:verify).returns(true)

      expects_command_to_output(/Verified certificate '#{name}'/, 0)
    end
  end
end
