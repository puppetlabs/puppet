require 'spec_helper'

require 'puppet/context/trusted_information'

describe Puppet::Context::TrustedInformation do
  let(:key) do
    key = Puppet::SSL::Key.new("myname")
    key.generate
    key
  end

  let(:csr) do
    csr = Puppet::SSL::CertificateRequest.new("csr")
    csr.generate(key, :extension_requests => {
      '1.3.6.1.4.1.15.1.2.1' => 'Ignored CSR extension',

      '1.3.6.1.4.1.34380.1.2.1' => 'CSR specific info',
      '1.3.6.1.4.1.34380.1.2.2' => 'more CSR specific info',
    })
    csr
  end

  let(:cert) do
    cert = Puppet::SSL::Certificate.from_instance(Puppet::SSL::CertificateFactory.build('ca', csr, csr.content, 1))

    # The cert must be signed so that it can be successfully be DER-decoded later
    signer = Puppet::SSL::CertificateSigner.new
    signer.sign(cert.content, key.content)
    cert
  end

  context "when remote" do
    it "has no cert information when it isn't authenticated" do
      trusted = Puppet::Context::TrustedInformation.remote(false, 'ignored', nil)

      expect(trusted.authenticated).to eq(false)
      expect(trusted.certname).to be_nil
      expect(trusted.extensions).to eq({})
    end

    it "is remote and has certificate information when it is authenticated" do
      trusted = Puppet::Context::TrustedInformation.remote(true, 'cert name', cert)

      expect(trusted.authenticated).to eq('remote')
      expect(trusted.certname).to eq('cert name')
      expect(trusted.extensions).to eq({
        '1.3.6.1.4.1.34380.1.2.1' => 'CSR specific info',
        '1.3.6.1.4.1.34380.1.2.2' => 'more CSR specific info',
      })
      expect(trusted.hostname).to eq('cert name')
      expect(trusted.domain).to be_nil
    end

    it "is remote but lacks certificate information when it is authenticated" do
      Puppet.expects(:info).once.with("TrustedInformation expected a certificate, but none was given.")

      trusted = Puppet::Context::TrustedInformation.remote(true, 'cert name', nil)

      expect(trusted.authenticated).to eq('remote')
      expect(trusted.certname).to eq('cert name')
      expect(trusted.extensions).to eq({})
    end
  end

  context "when local" do
    it "is authenticated local with the nodes clientcert" do
      node = Puppet::Node.new('testing', :parameters => { 'clientcert' => 'cert name' })

      trusted = Puppet::Context::TrustedInformation.local(node)

      expect(trusted.authenticated).to eq('local')
      expect(trusted.certname).to eq('cert name')
      expect(trusted.extensions).to eq({})
      expect(trusted.hostname).to eq('cert name')
      expect(trusted.domain).to be_nil
    end

    it "is authenticated local with no clientcert when there is no node" do
      trusted = Puppet::Context::TrustedInformation.local(nil)

      expect(trusted.authenticated).to eq('local')
      expect(trusted.certname).to be_nil
      expect(trusted.extensions).to eq({})
      expect(trusted.hostname).to be_nil
      expect(trusted.domain).to be_nil
    end
  end

  it "converts itself to a hash" do
    trusted = Puppet::Context::TrustedInformation.remote(true, 'cert name', cert)

    expect(trusted.to_h).to eq({
      'authenticated' => 'remote',
      'certname' => 'cert name',
      'extensions' => {
        '1.3.6.1.4.1.34380.1.2.1' => 'CSR specific info',
        '1.3.6.1.4.1.34380.1.2.2' => 'more CSR specific info',
      },
      'hostname' => 'cert name',
      'domain' => nil
    })
  end

  it "extracts domain and hostname from certname" do
    trusted = Puppet::Context::TrustedInformation.remote(true, 'hostname.domain.long', cert)

    expect(trusted.to_h).to eq({
      'authenticated' => 'remote',
      'certname' => 'hostname.domain.long',
      'extensions' => {
        '1.3.6.1.4.1.34380.1.2.1' => 'CSR specific info',
        '1.3.6.1.4.1.34380.1.2.2' => 'more CSR specific info',
      },
      'hostname' => 'hostname',
      'domain' => 'domain.long'
    })
  end

  it "freezes the hash" do
    trusted = Puppet::Context::TrustedInformation.remote(true, 'cert name', cert)

    expect(trusted.to_h).to be_deeply_frozen
  end

  matcher :be_deeply_frozen do
    match do |actual|
      unfrozen_items(actual).empty?
    end

    failure_message do |actual|
      "expected all items to be frozen but <#{unfrozen_items(actual).join(', ')}> was not"
    end

    define_method :unfrozen_items do |actual|
      unfrozen = []
      stack = [actual]
      while item = stack.pop
        if !item.frozen?
          unfrozen.push(item)
        end

        case item
        when Hash
          stack.concat(item.keys)
          stack.concat(item.values)
        when Array
          stack.concat(item)
        end
      end

      unfrozen
    end
  end
end
