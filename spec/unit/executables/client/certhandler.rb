#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/executables/client/certhandler'

cert_handler = Puppet::Executables::Client::CertHandler

describe cert_handler, "when handling certificates" do
    before do 
        @caclient = mock('caclient')
        caclient_class = mock('caclient_class')
        caclient_class.stubs(:new).returns(@caclient)
        Puppet::Network::Client.stubs(:ca).returns(caclient_class)
    end

    it "should return true if the certificate exists" do
        @caclient.expects(:read_cert).returns(true)
        cert_handler.new(1,true).read_retrieve.should be_true
    end
    
    it "should return false when getting a new cert" do
        @caclient.expects(:read_cert).returns(true)
        @caclient.stubs(:request_cert).returns(true)
        ch = cert_handler.new(1,true)
        ch.stubs(:read_cert).returns(false)
        ch.read_retrieve.should be_false
    end

    describe "when reading or retrieving the certificate" do
        before do
            @handler = cert_handler.new(1,true)
        end

        it "should attempt to read the certificate" do
            @handler.expects(:read_cert).returns true
            @handler.read_retrieve
        end

        it "should delegate to the ca client to read the certificate" do
            @caclient.expects(:read_cert).returns(true)
            @handler.read_retrieve
        end

        it "should not attempt to retrieve a certificate if one can be read" do
            @handler.stubs(:read_cert).returns true
            @handler.expects(:retrieve_cert).never
            @handler.read_retrieve
        end

        it "should attempt to retrieve a certificate if none can be read" do
            @handler.stubs(:read_cert).returns false
            @handler.expects(:retrieve_cert)
            @handler.read_retrieve
        end

        it "should delegate to caclient to retrieve a certificate" do
            @handler.stubs(:read_cert).returns false
            @caclient.expects(:request_cert).returns(true)
            @handler.stubs(:read_new_cert).returns(true)
            @handler.read_retrieve
        end

        it "should return true if the certificate exists" do
            @handler.stubs(:read_cert).returns true
            @handler.read_retrieve.should be_true
        end

        it "should return false when getting a new cert" do
            #This is the second call to httppool that happens in 'read_new_cert'
            @caclient.expects(:read_cert).returns(true)
            @caclient.stubs(:request_cert).returns(true)
            @handler.stubs(:read_cert).returns(false)
            @handler.read_retrieve.should be_false
        end
    end

    describe "when waiting for cert" do
        before do
            @handler = cert_handler.new(1,false)
            @handler.stubs(:read_cert).returns false
            #all waiting for cert tests should loop, which will always happen if sleep is called
            #yeah, I put the expectation in the setup, deal with it
            @handler.expects(:sleep).with(1)

            #This is needed to get out of the loop
            @handler.stubs(:read_new_cert).returns(true)
        end

        it "should loop when the cert request does not return a certificate" do
            @caclient.stubs(:request_cert).times(2).returns(false).then.returns(true)
            @handler.retrieve_cert
        end

        it "should loop when the cert request raises an Error" do
            @caclient.stubs(:request_cert).times(2).raises(StandardError, 'Testing').then.returns(true)
            @handler.retrieve_cert
        end
        
        it "should loop when the new cert can't be read" do
            @caclient.stubs(:request_cert).returns(true)
            @handler.stubs(:read_new_cert).times(2).returns(false).then.returns(true)
            @handler.retrieve_cert
        end
    end

    describe "when in one time mode" do
        before do
            #true puts us in onetime mode
            @handler = cert_handler.new(1,true)
            @handler.stubs(:read_cert).returns false
        end

        it "should exit if the cert request does not return a certificate" do
            @caclient.stubs(:request_cert).returns(false)
            @handler.expects(:exit).with(1).raises(SystemExit)
            lambda { @handler.retrieve_cert }.should raise_error(SystemExit)
        end


        it "should exit if the cert request raises an exception" do
            @caclient.stubs(:request_cert).raises(StandardError, 'Testing')
            @handler.expects(:exit).with(23).raises(SystemExit)
            lambda { @handler.retrieve_cert }.should raise_error(SystemExit)
        end
        
        it "should exit if the new cert can't be read" do
            @caclient.stubs(:request_cert).returns(true)
            #this is the second, call to httppool inside read_new_cert
            @caclient.stubs(:read_cert).returns(false)
            @handler.expects(:exit).with(34).raises(SystemExit)
            lambda { @handler.retrieve_cert }.should raise_error(SystemExit)
        end
    end
end
