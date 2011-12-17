#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/ocsp/request'
require 'puppet/ssl/ocsp/responder'

describe Puppet::SSL::Ocsp::Responder do
  include PuppetSpec::Files

  def make_certs(*crt_names)
    Array(crt_names).map do |name|
      a = Puppet::SSL::Host.new(name) ; a.generate ; a
    end
  end

  describe "#respond" do
    before(:each) do
      Puppet.run_mode.stubs(:master?).returns(true)

      Puppet[:ssldir] = tmpdir("ssldir")

      Puppet::SSL::Host.ca_location = :only
      Puppet[:certificate_revocation] = true

      Puppet::SSL::CertificateAuthority.stubs(:instance).returns(
          # ...and this actually does the directory creation, etc.
          Puppet::SSL::CertificateAuthority.new
      )

      @ocsp = Puppet::SSL::Ocsp::Request.new("n/a")
      @to_check, @sign_with = make_certs('to_check', 'sign_with')
      @ocsp.generate(@to_check.certificate, @sign_with.certificate, @sign_with.key, Puppet::SSL::CertificateAuthority.instance)
    end

    it "should return an error response if we're not a CA" do
      Puppet::SSL::CertificateAuthority.stubs(:instance).returns(nil)

      Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.status.should == OpenSSL::OCSP::RESPONSE_STATUS_INTERNALERROR
    end

    it "should return an error if no certificate were verified" do
      content = OpenSSL::OCSP::Request.new
      content.add_nonce
      request = Puppet::SSL::Ocsp::Request.new("n/a")
      request.content = content

      Puppet::SSL::Ocsp::Responder.respond(request).content.status.should == OpenSSL::OCSP::RESPONSE_STATUS_MALFORMEDREQUEST
    end

    it "should return an unknown response if certificate doesn't originate from our CA" do
    end

    it "should return status for the verified certificate" do
      Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.basic.status.first[0].serial.should == @to_check.certificate.content.serial
    end

    it "should return revocation status for the verified certificate" do
      Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.basic.status.first[1].should == OpenSSL::OCSP::V_CERTSTATUS_GOOD
    end

    describe "with a revoked certificate" do
      before(:each) do
        Puppet::SSL::CertificateAuthority.instance.revoke("to_check")
      end

      it "should return revocation status" do
        Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.basic.status.first[1].should == OpenSSL::OCSP::V_CERTSTATUS_REVOKED
      end

      it "should return revocation reason" do
        Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.basic.status.first[2].should == OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE
      end

      it "should return revocation time" do
        Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.basic.status.first[3].should be_a(Time)
      end

      it "should return request server time" do
        Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.basic.status.first[4].should be_a(Time)
      end

      it "should return this request ttl" do
        Puppet::SSL::Ocsp::Responder.respond(@ocsp).content.basic.status.first[5].should be_a(Time)
      end
    end
  end
end