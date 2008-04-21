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

    it "should be a ca host if its name matches the CA_NAME" do
        Puppet::SSL::Host.stubs(:ca_name).returns "yayca"
        Puppet::SSL::Host.new("yayca").should be_ca
    end

    it "should have a method for determining the CA location" do
        Puppet::SSL::Host.should respond_to(:ca_location)
    end

    it "should have a method for specifying the CA location" do
        Puppet::SSL::Host.should respond_to(:ca_location=)
    end

    describe "when specifying the CA location" do
        before do
            [Puppet::SSL::Key, Puppet::SSL::Certificate, Puppet::SSL::CertificateRequest, Puppet::SSL::CertificateRevocationList].each do |klass|
                klass.stubs(:terminus_class=)
                klass.stubs(:cache_class=)
            end
        end

        it "should support the location ':local'" do
            lambda { Puppet::SSL::Host.ca_location = :local }.should_not raise_error
        end

        it "should support the location ':remote'" do
            lambda { Puppet::SSL::Host.ca_location = :remote }.should_not raise_error
        end

        it "should support the location ':none'" do
            lambda { Puppet::SSL::Host.ca_location = :none }.should_not raise_error
        end

        it "should not support other modes" do
            lambda { Puppet::SSL::Host.ca_location = :whatever }.should raise_error(ArgumentError)
        end

        describe "as 'local'" do
            it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest as :file" do
                Puppet::SSL::Certificate.expects(:cache_class=).with :file
                Puppet::SSL::CertificateRequest.expects(:cache_class=).with :file
                Puppet::SSL::CertificateRevocationList.expects(:cache_class=).with :file

                Puppet::SSL::Host.ca_location = :local
            end

            it "should set the terminus class for Key as :file" do
                Puppet::SSL::Key.expects(:terminus_class=).with :file

                Puppet::SSL::Host.ca_location = :local
            end

            it "should set the terminus class for Certificate, CertificateRevocationList, and CertificateRequest as :ca" do
                Puppet::SSL::Certificate.expects(:terminus_class=).with :ca
                Puppet::SSL::CertificateRequest.expects(:terminus_class=).with :ca
                Puppet::SSL::CertificateRevocationList.expects(:terminus_class=).with :ca

                Puppet::SSL::Host.ca_location = :local
            end
        end

        describe "as 'remote'" do
            it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest as :file" do
                Puppet::SSL::Certificate.expects(:cache_class=).with :file
                Puppet::SSL::CertificateRequest.expects(:cache_class=).with :file
                Puppet::SSL::CertificateRevocationList.expects(:cache_class=).with :file

                Puppet::SSL::Host.ca_location = :remote
            end

            it "should set the terminus class for Key as :file" do
                Puppet::SSL::Key.expects(:terminus_class=).with :file

                Puppet::SSL::Host.ca_location = :remote
            end

            it "should set the terminus class for Certificate, CertificateRevocationList, and CertificateRequest as :rest" do
                Puppet::SSL::Certificate.expects(:terminus_class=).with :rest
                Puppet::SSL::CertificateRequest.expects(:terminus_class=).with :rest
                Puppet::SSL::CertificateRevocationList.expects(:terminus_class=).with :rest

                Puppet::SSL::Host.ca_location = :remote
            end
        end

        describe "as 'none'" do
            it "should set the terminus class for Key, Certificate, CertificateRevocationList, and CertificateRequest as :file" do
                Puppet::SSL::Key.expects(:terminus_class=).with :file
                Puppet::SSL::Certificate.expects(:terminus_class=).with :file
                Puppet::SSL::CertificateRequest.expects(:terminus_class=).with :file
                Puppet::SSL::CertificateRevocationList.expects(:terminus_class=).with :file

                Puppet::SSL::Host.ca_location = :none
            end
        end
    end

    it "should have a class method for destroying all files related to a given host" do
        Puppet::SSL::Host.should respond_to(:destroy)
    end

    describe "when destroying a host's SSL files" do
        before do
            Puppet::SSL::Key.stubs(:destroy).returns false
            Puppet::SSL::Certificate.stubs(:destroy).returns false
            Puppet::SSL::CertificateRequest.stubs(:destroy).returns false
        end

        it "should destroy its certificate, certificate request, and key" do
            Puppet::SSL::Key.expects(:destroy).with("myhost")
            Puppet::SSL::Certificate.expects(:destroy).with("myhost")
            Puppet::SSL::CertificateRequest.expects(:destroy).with("myhost")

            Puppet::SSL::Host.destroy("myhost")
        end

        it "should return true if any of the classes returned true" do
            Puppet::SSL::Certificate.expects(:destroy).with("myhost").returns true

            Puppet::SSL::Host.destroy("myhost").should be_true
        end

        it "should return false if none of the classes returned true" do
            Puppet::SSL::Host.destroy("myhost").should be_false
        end
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

        it "should find the key in the Key class and return the Puppet instance" do
            Puppet::SSL::Key.expects(:find).with("myname").returns(@key)
            @host.key.should equal(@key)
        end

        it "should be able to generate and save a new key" do
            Puppet::SSL::Key.expects(:new).with("myname").returns(@key)

            @key.expects(:generate)
            @key.expects(:save)

            @host.generate_key.should be_true
            @host.key.should equal(@key)
        end

        it "should return any previously found key without requerying" do
            Puppet::SSL::Key.expects(:find).with("myname").returns(@key).once
            @host.key.should equal(@key)
            @host.key.should equal(@key)
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

        it "should find the request in the Key class and return it and return the Puppet SSL request" do
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns @request

            @host.certificate_request.should equal(@request)
        end

        it "should generate a new key when generating the cert request if no key exists" do
            Puppet::SSL::CertificateRequest.expects(:new).with("myname").returns @request

            key = stub 'key', :public_key => mock("public_key"), :content => "mycontent"

            @host.expects(:key).times(2).returns(nil).then.returns(key)
            @host.expects(:generate_key).returns(key)

            @request.stubs(:generate)
            @request.stubs(:save)

            @host.generate_certificate_request
        end

        it "should be able to generate and save a new request using the private key" do
            Puppet::SSL::CertificateRequest.expects(:new).with("myname").returns @request

            key = stub 'key', :public_key => mock("public_key"), :content => "mycontent"
            @host.stubs(:key).returns(key)
            @request.expects(:generate).with("mycontent")
            @request.expects(:save)

            @host.generate_certificate_request.should be_true
            @host.certificate_request.should equal(@request)
        end

        it "should return any previously found request without requerying" do
            Puppet::SSL::CertificateRequest.expects(:find).with("myname").returns(@request).once

            @host.certificate_request.should equal(@request)
            @host.certificate_request.should equal(@request)
        end
    end

    describe "when managing its certificate" do
        before do
            @realcert = mock 'certificate'
            @cert = stub 'cert', :content => @realcert
        end

        it "should find the certificate in the Certificate class and return the Puppet certificate instance" do
            Puppet::SSL::Certificate.expects(:find).with("myname").returns @cert

            @host.certificate.should equal(@cert)
        end

        it "should return any previously found certificate" do
            Puppet::SSL::Certificate.expects(:find).with("myname").returns(@cert).once

            @host.certificate.should equal(@cert)
            @host.certificate.should equal(@cert)
        end
    end

    it "should have a method for listing certificate hosts" do
        Puppet::SSL::Host.should respond_to(:search)
    end

    describe "when listing certificate hosts" do
        it "should default to listing all clients with any file types" do
            Puppet::SSL::Key.expects(:search).returns []
            Puppet::SSL::Certificate.expects(:search).returns []
            Puppet::SSL::CertificateRequest.expects(:search).returns []
            Puppet::SSL::Host.search
        end

        it "should be able to list only clients with a key" do
            Puppet::SSL::Key.expects(:search).returns []
            Puppet::SSL::Certificate.expects(:search).never
            Puppet::SSL::CertificateRequest.expects(:search).never
            Puppet::SSL::Host.search :for => Puppet::SSL::Key
        end

        it "should be able to list only clients with a certificate" do
            Puppet::SSL::Key.expects(:search).never
            Puppet::SSL::Certificate.expects(:search).returns []
            Puppet::SSL::CertificateRequest.expects(:search).never
            Puppet::SSL::Host.search :for => Puppet::SSL::Certificate
        end

        it "should be able to list only clients with a certificate request" do
            Puppet::SSL::Key.expects(:search).never
            Puppet::SSL::Certificate.expects(:search).never
            Puppet::SSL::CertificateRequest.expects(:search).returns []
            Puppet::SSL::Host.search :for => Puppet::SSL::CertificateRequest
        end

        it "should return a Host instance created with the name of each found instance" do
            key = stub 'key', :name => "key"
            cert = stub 'cert', :name => "cert"
            csr = stub 'csr', :name => "csr"

            Puppet::SSL::Key.expects(:search).returns [key]
            Puppet::SSL::Certificate.expects(:search).returns [cert]
            Puppet::SSL::CertificateRequest.expects(:search).returns [csr]

            returned = []
            %w{key cert csr}.each do |name|
                result = mock(name)
                returned << result
                Puppet::SSL::Host.expects(:new).with(name).returns result
            end

            result = Puppet::SSL::Host.search
            returned.each do |r|
                result.should be_include(r)
            end
        end
    end
end
