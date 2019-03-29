require 'spec_helper'
require 'puppet/test_ca'

require 'puppet/ssl/host'

describe Puppet::SSL::Host, if: !Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("host_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir
    Puppet.settings.use :main, :ssl

    @host = Puppet::SSL::Host.new("luke.madstop.com")
    allow(@host).to receive(:submit_certificate_request)

    @ca = Puppet::TestCa.new
    Puppet::Util.replace_file(Puppet[:localcacert], 0644) do |f|
      f.write(@ca.ca_cert.to_s)
    end
    Puppet::Util.replace_file(Puppet[:hostcrl], 0644) do |f|
      f.write(@ca.ca_crl.to_s)
    end
  end

  describe "when managing its key" do
    it "should be able to generate and save a key" do
      @host.generate_key
    end

    it "should save the key such that the Indirector can find it" do
      @host.generate_key

      expect(Puppet::SSL::Key.indirection.find(@host.name).content.to_s).to eq(@host.key.to_s)
    end

    it "should save the private key into the :privatekeydir" do
      @host.generate_key
      expect(File.read(File.join(Puppet.settings[:privatekeydir], "luke.madstop.com.pem"))).to eq(@host.key.to_s)
    end
  end

  describe "when managing its certificate request" do
    it "should be able to generate and save a certificate request" do
      @host.generate_certificate_request
    end

    it "should save the certificate request such that the Indirector can find it" do
      @host.generate_certificate_request

      expect(Puppet::SSL::CertificateRequest.indirection.find(@host.name).content.to_s).to eq(@host.certificate_request.to_s)
    end

    it "should save the private certificate request into the :privatekeydir" do
      @host.generate_certificate_request
      expect(File.read(File.join(Puppet.settings[:requestdir], "luke.madstop.com.pem"))).to eq(@host.certificate_request.to_s)
    end
  end

  it "should pass the verification of its own SSL store", :unless => Puppet.features.microsoft_windows? do
    @host.generate_certificate_request
    cert = @ca.sign(@host.certificate_request.content)
    Puppet::Util.replace_file(File.join(Puppet[:certdir], "#{@host.name}.pem"), 0644) do |f|
      f.write(cert)
    end

    expect(@host.ssl_store.verify(@host.certificate.content)).to be_truthy
  end
end
