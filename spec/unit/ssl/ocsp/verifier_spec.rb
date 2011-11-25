#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/ocsp/request'
require 'puppet/ssl/ocsp/verifier'

describe Puppet::SSL::Ocsp::Verifier do
  include PuppetSpec::Files

  before :each do
    Puppet.run_mode.stubs(:master?).returns(true)
    Puppet[:ca]     = true
    Puppet[:ssldir] = tmpdir("ocsp-ssldir")

    Puppet::SSL::Host.ca_location = :only
    Puppet[:certificate_revocation] = true

    # This is way more intimate than I want to be with the implementation, but
    # there doesn't seem any other way to test this. --daniel 2011-07-18
    Puppet::SSL::CertificateAuthority.stubs(:instance).returns(
        # ...and this actually does the directory creation, etc.
        Puppet::SSL::CertificateAuthority.new
    )

    # we're forcing non-rest so that we can check
    # the request and the response
    Puppet::SSL::Host.stubs(:ca_location=)
  end

  def make_certs(*crt_names)
    Array(crt_names).map do |name|
      a = Puppet::SSL::Host.new(name) ; a.generate ; a
    end
  end

  it "should generate a valid response" do
    host = make_certs('certificate').first
    response = Puppet::SSL::Ocsp::Verifier.verify(host.certificate, Puppet::SSL::Host.localhost).first
    response[:serial].should == host.certificate.content.serial
    response[:valid].should be_true
  end

  it "should generate an invalid response for revoked certificate" do
    host = make_certs('certificate').first
    Puppet::SSL::CertificateAuthority.instance.revoke("certificate")
    response = Puppet::SSL::Ocsp::Verifier.verify(host.certificate, Puppet::SSL::Host.localhost).first
    response[:serial].should == host.certificate.content.serial
    response[:valid].should be_false
  end

  it "should generate an error if an error occured" do
    host = make_certs('certificate').first
    invalid = Puppet::SSL::Ocsp::Responder.ocsp_invalid_request_response
    Puppet::SSL::Ocsp::Request.indirection.stubs(:save).returns(invalid)
    lambda { Puppet::SSL::Ocsp::Verifier.verify(host.certificate, Puppet::SSL::Host.localhost).first }.should raise_error(Puppet::SSL::Ocsp::Response::VerificationError)
  end
end