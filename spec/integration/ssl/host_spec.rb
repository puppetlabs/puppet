#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/host'

# REMIND: Fails on windows because there is no user provider yet
describe Puppet::SSL::Host, :fails_on_windows => true do
  include PuppetSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("host_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir
    Puppet.settings[:group] = Process.gid

    Puppet::SSL::Host.ca_location = :local

    @host = Puppet::SSL::Host.new("luke.madstop.com")
    @ca = Puppet::SSL::CertificateAuthority.new
  end

  after {
    Puppet::SSL::Host.ca_location = :none

    Puppet.settings.clear
  }

  it "should be considered a CA host if its name is equal to 'ca'" do
    Puppet::SSL::Host.new(Puppet::SSL::CA_NAME).should be_ca
  end

  describe "when managing its key" do
    it "should be able to generate and save a key" do
      @host.generate_key
    end

    it "should save the key such that the Indirector can find it" do
      @host.generate_key

      Puppet::SSL::Key.indirection.find(@host.name).content.to_s.should == @host.key.to_s
    end

    it "should save the private key into the :privatekeydir" do
      @host.generate_key
      File.read(File.join(Puppet.settings[:privatekeydir], "luke.madstop.com.pem")).should == @host.key.to_s
    end
  end

  describe "when managing its certificate request" do
    it "should be able to generate and save a certificate request" do
      @host.generate_certificate_request
    end

    it "should save the certificate request such that the Indirector can find it" do
      @host.generate_certificate_request

      Puppet::SSL::CertificateRequest.indirection.find(@host.name).content.to_s.should == @host.certificate_request.to_s
    end

    it "should save the private certificate request into the :privatekeydir" do
      @host.generate_certificate_request
      File.read(File.join(Puppet.settings[:requestdir], "luke.madstop.com.pem")).should == @host.certificate_request.to_s
    end
  end

  describe "when the CA host" do
    it "should never store its key in the :privatekeydir" do
      Puppet.settings.use(:main, :ssl, :ca)
      @ca = Puppet::SSL::Host.new(Puppet::SSL::Host.ca_name)
      @ca.generate_key

      FileTest.should_not be_exist(File.join(Puppet[:privatekeydir], "ca.pem"))
    end
  end

  it "should pass the verification of its own SSL store", :unless => Puppet.features.microsoft_windows? do
    @host.generate
    @ca = Puppet::SSL::CertificateAuthority.new
    @ca.sign(@host.name)

    @host.ssl_store.verify(@host.certificate.content).should be_true
  end
end
