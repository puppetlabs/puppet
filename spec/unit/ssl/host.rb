#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/host'

describe Puppet::SSL::Host do
    before do
        @class = Puppet::SSL::Host
        @host = @class.new("myname")
    end

    after do
        # Cleaned out any cached localhost instance.
        Puppet::Util::Cacher.expire
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

    it "should have a method for retrieving the default ssl host" do
        Puppet::SSL::Host.should respond_to(:ca_location=)
    end

    it "should have a method for producing an instance to manage the local host's keys" do
        Puppet::SSL::Host.should respond_to(:localhost)
    end

    it "should generate the certificate for the localhost instance if no certificate is available" do
        host = stub 'host', :key => nil
        Puppet::SSL::Host.expects(:new).returns host

        host.expects(:certificate).returns nil
        host.expects(:generate)

        Puppet::SSL::Host.localhost.should equal(host)
    end

    it "should always read the key for the localhost instance in from disk" do
        host = stub 'host', :certificate => "eh"
        Puppet::SSL::Host.expects(:new).returns host

        host.expects(:key)

        Puppet::SSL::Host.localhost
    end

    it "should cache the localhost instance" do
        host = stub 'host', :certificate => "eh", :key => 'foo'
        Puppet::SSL::Host.expects(:new).once.returns host

        Puppet::SSL::Host.localhost.should == Puppet::SSL::Host.localhost
    end

    it "should be able to expire the cached instance" do
        one = stub 'host1', :certificate => "eh", :key => 'foo'
        two = stub 'host2', :certificate => "eh", :key => 'foo'
        Puppet::SSL::Host.expects(:new).times(2).returns(one).then.returns(two)

        Puppet::SSL::Host.localhost.should equal(one)
        Puppet::Util::Cacher.expire
        Puppet::SSL::Host.localhost.should equal(two)
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

        it "should support the location ':only'" do
            lambda { Puppet::SSL::Host.ca_location = :only }.should_not raise_error
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

        describe "as 'only'" do
            it "should set the terminus class for Key, Certificate, CertificateRevocationList, and CertificateRequest as :ca" do
                Puppet::SSL::Key.expects(:terminus_class=).with :ca
                Puppet::SSL::Certificate.expects(:terminus_class=).with :ca
                Puppet::SSL::CertificateRequest.expects(:terminus_class=).with :ca
                Puppet::SSL::CertificateRevocationList.expects(:terminus_class=).with :ca

                Puppet::SSL::Host.ca_location = :only
            end

            it "should reset the cache class for Certificate, CertificateRevocationList, and CertificateRequest to nil" do
                Puppet::SSL::Certificate.expects(:cache_class=).with nil
                Puppet::SSL::CertificateRequest.expects(:cache_class=).with nil
                Puppet::SSL::CertificateRevocationList.expects(:cache_class=).with nil

                Puppet::SSL::Host.ca_location = :only
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

    describe "when initializing" do
        it "should default its name to the :certname setting" do
            Puppet.settings.expects(:value).with(:certname).returns "myname"

            Puppet::SSL::Host.new.name.should == "myname"
        end

        it "should downcase a passed in name" do
            Puppet::SSL::Host.new("Host.Domain.Com").name.should == "host.domain.com"
        end

        it "should downcase the certname if it's used" do
            Puppet.settings.expects(:value).with(:certname).returns "Host.Domain.Com"
            Puppet::SSL::Host.new().name.should == "host.domain.com"
        end

        it "should indicate that it is a CA host if its name matches the ca_name constant" do
            Puppet::SSL::Host.stubs(:ca_name).returns "myca"
            Puppet::SSL::Host.new("myca").should be_ca
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

        it "should not retain keys that could not be saved" do
            Puppet::SSL::Key.expects(:new).with("myname").returns(@key)

            @key.stubs(:generate)
            @key.expects(:save).raises "eh"

            lambda { @host.generate_key }.should raise_error
            @host.key.should be_nil
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

        it "should not keep its certificate request in memory if the request cannot be saved" do
            Puppet::SSL::CertificateRequest.expects(:new).with("myname").returns @request

            key = stub 'key', :public_key => mock("public_key"), :content => "mycontent"
            @host.stubs(:key).returns(key)
            @request.stubs(:generate)
            @request.expects(:save).raises "eh"

            lambda { @host.generate_certificate_request }.should raise_error

            @host.certificate_request.should be_nil
        end
    end

    describe "when managing its certificate" do
        before do
            @realcert = mock 'certificate'
            @realcert.stubs(:check_private_key).with('private key').returns true

            @cert = stub 'cert', :content => @realcert, :expired? => false

            @host.stubs(:key).returns stub("key",:content => 'private key' )
        end

        it "should find the CA certificate if it does not have a certificate" do
            Puppet::SSL::Certificate.expects(:find).with(Puppet::SSL::CA_NAME).returns mock("cacert")
            Puppet::SSL::Certificate.stubs(:find).with("myname").returns @cert

            @host.certificate
        end

        it "should not find the CA certificate if it is the CA host" do
            @host.expects(:ca?).returns true
            Puppet::SSL::Certificate.stubs(:find)
            Puppet::SSL::Certificate.expects(:find).with(Puppet::SSL::CA_NAME).never

            @host.certificate
        end

        it "should return nil if it cannot find a CA certificate" do
            Puppet::SSL::Certificate.expects(:find).with(Puppet::SSL::CA_NAME).returns nil
            Puppet::SSL::Certificate.expects(:find).with("myname").never

            @host.certificate.should be_nil
        end

        it "should find the key if it does not have one" do
            Puppet::SSL::Certificate.stubs(:find)
            @host.expects(:key).returns mock("key")

            @host.certificate
        end

        it "should generate the key if one cannot be found" do
            Puppet::SSL::Certificate.stubs(:find)

            @host.expects(:key).returns nil
            @host.expects(:generate_key)

            @host.certificate
        end

        it "should find the certificate in the Certificate class and return the Puppet certificate instance" do
            Puppet::SSL::Certificate.expects(:find).with(Puppet::SSL::CA_NAME).returns mock("cacert")
            Puppet::SSL::Certificate.expects(:find).with("myname").returns @cert

            @host.certificate.should equal(@cert)
        end

        it "should immediately expire the cached copy if the found certificate does not match the private key" do
            @realcert.expects(:check_private_key).with('private key').returns false

            Puppet::SSL::Certificate.stubs(:find).returns @cert
            Puppet::SSL::Certificate.expects(:expire).with("myname")

            @host.certificate
        end

        it "should not return a certificate if it does not match the private key" do
            @realcert.expects(:check_private_key).with('private key').returns false

            Puppet::SSL::Certificate.stubs(:find).returns @cert
            Puppet::SSL::Certificate.stubs(:expire).with("myname")

            @host.certificate.should == nil
        end

        it "should return any previously found certificate" do
            Puppet::SSL::Certificate.expects(:find).with(Puppet::SSL::CA_NAME).returns mock("cacert")
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

    it "should have a method for generating all necessary files" do
        Puppet::SSL::Host.new("me").should respond_to(:generate)
    end

    describe "when generating files" do
        before do
            @host = Puppet::SSL::Host.new("me")
            @host.stubs(:generate_key)
            @host.stubs(:generate_certificate_request)
        end

        it "should generate a key if one is not present" do
            @host.stubs(:key).returns nil
            @host.expects(:generate_key)

            @host.generate
        end

        it "should generate a certificate request if one is not present" do
            @host.expects(:certificate_request).returns nil
            @host.expects(:generate_certificate_request)

            @host.generate
        end

        describe "and it can create a certificate authority" do
            before do
                @ca = mock 'ca'
                Puppet::SSL::CertificateAuthority.stubs(:instance).returns @ca
            end

            it "should use the CA to sign its certificate request if it does not have a certificate" do
                @host.expects(:certificate).returns nil

                @ca.expects(:sign).with(@host.name)

                @host.generate
            end
        end

        describe "and it cannot create a certificate authority" do
            before do
                Puppet::SSL::CertificateAuthority.stubs(:instance).returns nil
            end

            it "should seek its certificate" do
                @host.expects(:certificate)

                @host.generate
            end
        end
    end

    it "should have a method for creating an SSL store" do
        Puppet::SSL::Host.new("me").should respond_to(:ssl_store)
    end

    it "should always return the same store" do
        host = Puppet::SSL::Host.new("foo")
        store = mock 'store'
        store.stub_everything
        OpenSSL::X509::Store.expects(:new).returns store
        host.ssl_store.should equal(host.ssl_store)
    end

    describe "when creating an SSL store" do
        before do
            @host = Puppet::SSL::Host.new("me")
            @store = mock 'store'
            @store.stub_everything
            OpenSSL::X509::Store.stubs(:new).returns @store

            Puppet.settings.stubs(:value).with(:localcacert).returns "ssl_host_testing"

            Puppet::SSL::CertificateRevocationList.stubs(:find).returns(nil)
        end

        it "should accept a purpose" do
            @store.expects(:purpose=).with "my special purpose"
            @host.ssl_store("my special purpose")
        end

        it "should default to OpenSSL::X509::PURPOSE_ANY as the purpose" do
            @store.expects(:purpose=).with OpenSSL::X509::PURPOSE_ANY
            @host.ssl_store
        end

        it "should add the local CA cert file" do
            Puppet.settings.stubs(:value).with(:localcacert).returns "/ca/cert/file"
            @store.expects(:add_file).with "/ca/cert/file"
            @host.ssl_store
        end

        describe "and a CRL is available" do
            before do
                @crl = stub 'crl', :content => "real_crl"
                Puppet::SSL::CertificateRevocationList.stubs(:find).returns @crl
            end

            it "should add the CRL" do
                @store.expects(:add_crl).with "real_crl"
                @host.ssl_store
            end

            it "should set the flags to OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK" do
                @store.expects(:flags=).with OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK
                @host.ssl_store
            end
        end
    end

    describe "when waiting for a cert" do
        before do
            @host = Puppet::SSL::Host.new("me")
        end

        it "should generate its certificate request and attempt to read the certificate again if no certificate is found" do
            @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
            @host.expects(:generate)
            @host.wait_for_cert(1)
        end

        it "should catch and log errors during CSR saving" do
            @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
            @host.expects(:generate).raises(RuntimeError).then.returns nil
            @host.stubs(:sleep)
            @host.wait_for_cert(1)
        end

        it "should sleep and retry after failures saving the CSR if waitforcert is enabled" do
            @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
            @host.expects(:generate).raises(RuntimeError).then.returns nil
            @host.expects(:sleep).with(1)
            @host.wait_for_cert(1)
        end

        it "should exit after failures saving the CSR of waitforcert is disabled" do
            @host.expects(:certificate).returns(nil)
            @host.expects(:generate).raises(RuntimeError)
            @host.expects(:puts)
            @host.expects(:exit).with(1).raises(SystemExit)
            lambda { @host.wait_for_cert(0) }.should raise_error(SystemExit)
        end

        it "should exit if the wait time is 0 and it can neither find nor retrieve a certificate" do
            @host.stubs(:certificate).returns nil
            @host.expects(:generate)
            @host.expects(:puts)
            @host.expects(:exit).with(1).raises(SystemExit)
            lambda { @host.wait_for_cert(0) }.should raise_error(SystemExit)
        end

        it "should sleep for the specified amount of time if no certificate is found after generating its certificate request" do
            @host.expects(:certificate).times(3).returns(nil).then.returns(nil).then.returns "foo"
            @host.expects(:generate)

            @host.expects(:sleep).with(1)

            @host.wait_for_cert(1)
        end

        it "should catch and log exceptions during certificate retrieval" do
            @host.expects(:certificate).times(3).returns(nil).then.raises(RuntimeError).then.returns("foo")
            @host.stubs(:generate)
            @host.stubs(:sleep)

            Puppet.expects(:err)

            @host.wait_for_cert(1)
        end
    end
end
