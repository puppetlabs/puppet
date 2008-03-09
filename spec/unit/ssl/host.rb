#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/host'

describe Puppet::SSL::Host do
    before do
        @class = Puppet::SSL::Host
        @host = @class.new("myname")
    end

    it "should use any provided name as its name" do
        @host.name.should == "myname"
    end

    it "should retrieve its public key from its private key" do
        key = mock 'key'
        Puppet::SSL::Key.stubs(:find).returns(key)
        pubkey = mock 'public_key'
        key.expects(:public_key).returns pubkey

        @host.public_key.should equal(pubkey)
    end

    describe "when managing its private key" do
        it "should find the key in the Key class and return it" do
            key = mock 'key'
            Puppet::SSL::Key.expects(:find).with("myname").returns(key)
            @host.key.should equal(key)
        end

        it "should generate and save a new key if none is found" do
            key = mock 'key'
            Puppet::SSL::Key.stubs(:find).with("myname").returns(nil)

            Puppet::SSL::Key.expects(:new).with("myname").returns(key)

            key.expects(:generate)
            key.expects(:save)

            @host.key.should equal(key)
        end

        it "should return any previously found key without requerying" do
            key = mock 'key'
            Puppet::SSL::Key.expects(:find).with("myname").returns(key).once
            @host.key.should equal(key)
            @host.key.should equal(key)
        end
    end

    describe "when managing its certificate request" do
        it "should find the request in the Key class and return it" do
            request = mock 'request'
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns request

            @host.certificate_request.should equal(request)
        end

        it "should generate a new request using the private key if none is found" do
            request = mock 'request'
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns nil
            Puppet::SSL::CertificateRequest.expects(:new).with("myname").returns request

            key = stub 'key', :public_key => mock("public_key")
            @host.stubs(:key).returns(key)
            request.expects(:generate).with(key)
            request.expects(:save)

            @host.certificate_request.should equal(request)
        end

        it "should return any previously found request without requerying" do
            request = mock 'request'
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns(request).once

            @host.certificate_request.should equal(request)
            @host.certificate_request.should equal(request)
        end
    end

    describe "when managing its certificate" do
        it "should find the certificate in the Certificate class" do
            cert = mock 'cert'
            Puppet::SSL::Certificate.expects(:find).with("myname").returns cert

            @host.certificate.should equal(cert)
        end

        it "should generate a new certificate if none is found" do
            cert = mock 'cert'
            Puppet::SSL::Certificate.expects(:find).with("myname").returns nil
            Puppet::SSL::Certificate.expects(:new).with("myname").returns cert

            # This will normally fail.
            cert.expects(:generate)

            @host.certificate
        end

        it "should return any previously found certificate" do
            cert = mock 'cert'
            Puppet::SSL::Certificate.expects(:find).with("myname").returns(cert).once

            @host.certificate.should equal(cert)
            @host.certificate.should equal(cert)
        end
    end

    describe "when being destroyed" do
        before do
            @host.stubs(:key).returns Puppet::SSL::Key.new("myname")
            @host.stubs(:certificate).returns Puppet::SSL::Certificate.new("myname")
            @host.stubs(:certificate_request).returns Puppet::SSL::CertificateRequest.new("myname")
        end

        it "should destroy its certificate, certificate request, and key" do
            Puppet::SSL::Key.expects(:destroy).with(@host.key)
            Puppet::SSL::Certificate.expects(:destroy).with(@host.certificate)
            Puppet::SSL::CertificateRequest.expects(:destroy).with(@host.certificate_request)

            @host.destroy
        end
    end
end
