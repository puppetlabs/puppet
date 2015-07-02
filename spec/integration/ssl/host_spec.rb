#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/host'

describe Puppet::SSL::Host do
  include PuppetSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("host_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir

    Puppet::SSL::Host.ca_location = :local

    @host = Puppet::SSL::Host.new("luke.madstop.com")
    @ca = Puppet::SSL::CertificateAuthority.new
  end

  after {
    Puppet::SSL::Host.ca_location = :none
  }

  it "should be considered a CA host if its name is equal to 'ca'" do
    expect(Puppet::SSL::Host.new(Puppet::SSL::CA_NAME)).to be_ca
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

  describe "when the CA host" do
    it "should never store its key in the :privatekeydir" do
      Puppet.settings.use(:main, :ssl, :ca)
      @ca = Puppet::SSL::Host.new(Puppet::SSL::Host.ca_name)
      @ca.generate_key

      expect(Puppet::FileSystem.exist?(File.join(Puppet[:privatekeydir], "ca.pem"))).to be_falsey
    end
  end

  it "should pass the verification of its own SSL store", :unless => Puppet.features.microsoft_windows? do
    @host.generate
    @ca = Puppet::SSL::CertificateAuthority.new
    @ca.sign(@host.name)

    expect(@host.ssl_store.verify(@host.certificate.content)).to be_truthy
  end
end
