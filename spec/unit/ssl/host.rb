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
        realkey = mock 'realkey'
        key = stub 'key', :content => realkey
        Puppet::SSL::Key.stubs(:find).returns(key)
        pubkey = mock 'public_key'
        realkey.expects(:public_key).returns pubkey

        @host.public_key.should equal(pubkey)
    end

    it "should default to being a non-ca host" do
        @host.ca?.should be_false
    end

    it "should be able to be a ca host" do
        @host.ca = true
        @host.ca.should be_true
    end

    describe "when managing its private key" do
        before do
            @realkey = "mykey"
            @key = stub 'key', :content => @realkey
        end

        it "should return nil if the key is not set and cannot be found" do
            Puppet::SSL::Key.expects(:find).with("myname").returns(nil)
            @host.key.should be_nil
        end

        it "should find the key in the Key class and return the SSL key, not the wrapper" do
            Puppet::SSL::Key.expects(:find).with("myname").returns(@key)
            @host.key.should equal(@realkey)
        end

        it "should be able to generate and save a new key" do
            Puppet::SSL::Key.expects(:new).with("myname").returns(@key)

            @key.expects(:generate)
            @key.expects(:save).with(:in => :file)

            @host.generate_key.should be_true
            @host.key.should equal(@realkey)
        end

        it "should return any previously found key without requerying" do
            Puppet::SSL::Key.expects(:find).with("myname").returns(@key).once
            @host.key.should equal(@realkey)
            @host.key.should equal(@realkey)
        end
    end

    describe "when managing its certificate request" do
        before do
            @realrequest = "real request"
            @request = stub 'request', :content => @realrequest
        end

        it "should return nil if the key is not set and cannot be found" do
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns(nil)
            @host.certificate_request.should be_nil
        end

        it "should find the request in the Key class and return it and return the SSL request, not the wrapper" do
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns @request

            @host.certificate_request.should equal(@realrequest)
        end

        it "should generate a new key when generating the cert request if no key exists" do
            Puppet::SSL::CertificateRequest.expects(:new).with("myname").returns @request

            key = stub 'key', :public_key => mock("public_key")
            @host.expects(:generate_key).returns(key)

            @request.stubs(:generate)
            @request.stubs(:save).with(:in => :file)

            @host.generate_certificate_request
        end

        it "should be able to generate and save a new request using the private key" do
            Puppet::SSL::CertificateRequest.expects(:new).with("myname").returns @request

            key = stub 'key', :public_key => mock("public_key")
            @host.stubs(:key).returns(key)
            @request.expects(:generate).with(key)
            @request.expects(:save).with(:in => :file)

            @host.generate_certificate_request.should be_true
            @host.certificate_request.should equal(@realrequest)
        end

        it "should return any previously found request without requerying" do
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns(@request).once

            @host.certificate_request.should equal(@realrequest)
            @host.certificate_request.should equal(@realrequest)
        end
    end

    describe "when managing its certificate" do
        before do
            @realcert = mock 'certificate'
            @cert = stub 'cert', :content => @realcert
        end
        it "should find the certificate in the Certificate class and return the SSL certificate, not the wrapper" do
            Puppet::SSL::Certificate.expects(:find).with("myname").returns @cert

            @host.certificate.should equal(@realcert)
        end

        it "should generate a new certificate request when generating the cert if no request exists" do
            Puppet::SSL::Certificate.expects(:new).with("myname").returns @cert

            request = stub 'request'
            @host.expects(:generate_certificate_request)

            @cert.stubs(:generate)
            @cert.stubs(:save).with(:in => :file)

            @host.generate_certificate
        end

        it "should be able to generate and save a new certificate using the certificate request" do
            Puppet::SSL::Certificate.expects(:new).with("myname").returns @cert

            request = stub 'request'
            @host.stubs(:certificate_request).returns(request)
            @cert.expects(:generate).with(request).returns(true)
            @cert.expects(:save).with(:in => :file)

            @host.generate_certificate.should be_true
            @host.certificate.should equal(@realcert)
        end

        it "should return false if no certificate could be generated" do
            Puppet::SSL::Certificate.expects(:new).with("myname").returns @cert

            request = stub 'request'
            @host.stubs(:certificate_request).returns(request)
            @cert.expects(:generate).with(request).returns(false)

            @host.generate_certificate.should be_false
        end

        it "should return any previously found certificate" do
            Puppet::SSL::Certificate.expects(:find).with("myname").returns(@cert).once

            @host.certificate.should equal(@realcert)
            @host.certificate.should equal(@realcert)
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

    describe "when sending its CSR to the CA" do
        before do
            @realrequest = "real request"
            @request = stub 'request', :content => @realrequest

            @host.instance_variable_set("@certificate_request", @request)
        end

        it "should be able to send its CSR" do
            @request.expects(:save)

            @host.send_certificate_request
        end

        it "should default to sending its CSR to the :ca_file" do
            @request.expects(:save).with(:in => :ca_file)

            @host.send_certificate_request
        end

        it "should allow specification of another CA terminus" do
            @request.expects(:save).with(:in => :rest)

            @host.send_certificate_request :rest
        end
    end

    describe "when retrieving its signed certificate from the CA" do
        before do
            @realcert = "real cert"
            @cert = stub 'cert', :content => @realcert
        end

        it "should be able to send its CSR" do
            Puppet::SSL::Certificate.expects(:find).with { |*args| args[0] == @host.name }

            @host.retrieve_signed_certificate
        end

        it "should default to searching for its certificate in the :ca_file" do
            Puppet::SSL::Certificate.expects(:find).with { |*args| args[1] == {:in => :ca_file} }

            @host.retrieve_signed_certificate
        end

        it "should allow specification of another CA terminus" do
            Puppet::SSL::Certificate.expects(:find).with { |*args| args[1] == {:in => :rest} }

            @host.retrieve_signed_certificate :rest
        end

        it "should return true and set its certificate if retrieval was successful" do
            cert = stub 'cert', :content => "mycert", :save => nil
            Puppet::SSL::Certificate.stubs(:find).returns cert

            @host.retrieve_signed_certificate.should be_true
            @host.certificate.should == "mycert"
        end

        it "should save the retrieved certificate to the local disk" do
            cert = stub 'cert', :content => "mycert"
            Puppet::SSL::Certificate.stubs(:find).returns cert

            cert.expects(:save).with :in => :file

            @host.retrieve_signed_certificate
            @host.certificate
        end

        it "should return false and not set its certificate if retrieval was unsuccessful" do
            Puppet::SSL::Certificate.stubs(:find).returns nil

            @host.retrieve_signed_certificate.should be_false
            @host.certificate.should be_nil
        end
    end
end
