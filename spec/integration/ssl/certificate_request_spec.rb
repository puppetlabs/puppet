#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/certificate_request'

describe Puppet::SSL::CertificateRequest do
  include PuppetSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("csr_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir

    Puppet::SSL::Host.ca_location = :none

    @csr = Puppet::SSL::CertificateRequest.new("luke.madstop.com")

    @key = OpenSSL::PKey::RSA.new(512)

    # This is necessary so the terminus instances don't lie around.
    Puppet::SSL::CertificateRequest.indirection.termini.clear
  end

  it "should be able to generate CSRs" do
    @csr.generate(@key)
  end

  it "should be able to save CSRs" do
    Puppet::SSL::CertificateRequest.indirection.save(@csr)
  end

  it "should be able to find saved certificate requests via the Indirector" do
    @csr.generate(@key)
    Puppet::SSL::CertificateRequest.indirection.save(@csr)

    expect(Puppet::SSL::CertificateRequest.indirection.find("luke.madstop.com")).to be_instance_of(Puppet::SSL::CertificateRequest)
  end

  it "should save the completely CSR when saving" do
    @csr.generate(@key)
    Puppet::SSL::CertificateRequest.indirection.save(@csr)

    expect(Puppet::SSL::CertificateRequest.indirection.find("luke.madstop.com").content.to_s).to eq(@csr.content.to_s)
  end
end
