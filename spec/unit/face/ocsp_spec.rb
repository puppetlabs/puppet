#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:ocsp, '0.0.1'] do
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

  after do
    Puppet::SSL::Ocsp::Verifier.expire!
  end

  def make_certs(*crt_names)
    Array(crt_names).map do |name|
      a = Puppet::SSL::Host.new(name) ; a.generate ; a
    end
  end

  describe "#verify" do
    let :action do Puppet::Face[:ocsp, '0.0.1'].get_action(:verify) end

    it "should raise an error if certificate can't be found" do
      lambda { subject.verify('certificate') }.should raise_error
    end

    it "should raise an error if the local CA certificate can't be found" do
      make_certs('certificate')
      Puppet::SSL::Certificate.indirection.stubs(:find).returns(nil)
      lambda { subject.verify('certificate') }.should raise_error
    end

    it "should generate a valid response" do
      make_certs('certificate')
      response = subject.verify('certificate')
      response[:host].should == 'certificate'
      response[:valid].should be_true
    end

    it "should generate an invalid response for revoked certificate" do
      make_certs('certificate')
      Puppet::SSL::CertificateAuthority.instance.revoke("certificate")
      response = subject.verify('certificate')
      response[:host].should == 'certificate'
      response[:valid].should be_false
    end

    it "should generate an error if an error occured" do
      make_certs('certificate')
      invalid = Puppet::SSL::Ocsp::Responder.ocsp_invalid_request_response
      Puppet::SSL::Ocsp::Request.indirection.stubs(:save).returns(invalid)
      response = subject.verify('certificate')
      response[:host].should == 'certificate'
      response[:valid].should be_false
      response[:error].should == "OCSP Verification Error: malformedrequest"
    end
  end
end
