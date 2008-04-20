#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_revocation_list'

describe Puppet::SSL::CertificateRevocationList do
    before do
        @cert = stub 'cert', :subject => "mysubject"

        @class = Puppet::SSL::CertificateRevocationList
    end

    it "should default to the :file terminus" do
        @class.indirection.terminus_class.should == :file
    end

    describe "when an instance" do
        before do
            @class.any_instance.stubs(:read_or_generate)

            @crl = @class.new("whatever")
        end

        it "should always use 'crl' for its name" do
            @crl.name.should == "crl"
        end

        it "should have a content attribute" do
            @crl.should respond_to(:content)
        end
    end

    describe "when initializing" do
        it "should fail if :cacrl is set to false" do
            Puppet.settings.expects(:value).with(:cacrl).returns false
            lambda { @class.new("crl") }.should raise_error(Puppet::Error)
        end

        it "should fail if :cacrl is set to the string 'false'" do
            Puppet.settings.expects(:value).with(:cacrl).returns "false"
            lambda { @class.new("crl") }.should raise_error(Puppet::Error)
        end
    end

    describe "when generating the crl" do
        before do
            @real_crl = mock 'crl'
            @real_crl.stub_everything

            OpenSSL::X509::CRL.stubs(:new).returns(@real_crl)

            @class.any_instance.stubs(:read_or_generate)

            @crl = @class.new("crl")
        end

        it "should set its issuer to the subject of the passed certificate" do
            @real_crl.expects(:issuer=).with(@cert.subject)

            @crl.generate(@cert)
        end

        it "should set its version to 1" do
            @real_crl.expects(:version=).with(1)

            @crl.generate(@cert)
        end

        it "should create an instance of OpenSSL::X509::CRL" do
            OpenSSL::X509::CRL.expects(:new).returns(@real_crl)

            @crl.generate(@cert)
        end

        it "should set the content to the generated crl" do
            @crl.generate(@cert)
            @crl.content.should equal(@real_crl)
        end

        it "should return the generated crl" do
            @crl.generate(@cert).should equal(@real_crl)
        end
    end

    # This test suite isn't exactly complete, because the
    # SSL stuff is very complicated.  It just hits the high points.
    describe "when revoking a certificate" do
        before do
            @class.wrapped_class.any_instance.stubs(:issuer=)

            @crl = @class.new("crl")
            @crl.generate(@cert)
            @crl.content.stubs(:sign)

            @crl.stubs :save

            @key = mock 'key'
        end

        it "should require a serial number and the CA's private key" do
            lambda { @crl.revoke }.should raise_error(ArgumentError)
        end

        it "should default to OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE as the revocation reason" do
            # This makes it a bit more of an integration test than we'd normally like, but that's life
            # with openssl.
            reason = OpenSSL::ASN1::Enumerated(OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE)
            OpenSSL::ASN1.expects(:Enumerated).with(OpenSSL::OCSP::REVOKED_STATUS_KEYCOMPROMISE).returns reason

            @crl.revoke(1, @key)
        end

        it "should mark the CRL as updated" do
            time = Time.now
            Time.stubs(:now).returns time

            @crl.content.expects(:last_update=).with(time)

            @crl.revoke(1, @key)
        end

        it "should mark the CRL valid for five years" do
            time = Time.now
            Time.stubs(:now).returns time

            @crl.content.expects(:next_update=).with(time + (5 * 365*24*60*60))

            @crl.revoke(1, @key)
        end

        it "should sign the CRL with the CA's private key and a digest instance" do
            @crl.content.expects(:sign).with { |key, digest| key == @key and digest.is_a?(OpenSSL::Digest::SHA1) }
            @crl.revoke(1, @key)
        end

        it "should save the CRL" do
            @crl.expects :save
            @crl.revoke(1, @key)
        end
    end
end
