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
        Puppet::Network::HttpPool.expects(:read_cert).returns(true)
        cert_handler.new(1,true).read_retrieve.should be_true
    end
    
    it "should return false when getting a new cert" do
        Puppet::Network::HttpPool.expects(:read_cert).returns(true)
        @caclient.stubs(:request_cert).returns(true)
        ch = cert_handler.new(1,true)
        ch.stubs(:read_cert).returns(false)
        ch.read_retrieve.should be_false
    end

    describe "when waiting for cert" do
        it "should loop when the cert request does not return a certificate" do
            @caclient.stubs(:request_cert).times(2).returns(false).then.returns(true)
            ch = cert_handler.new(1,false)
            ch.expects(:sleep)
            ch.expects(:read_new_cert).returns(true)
            ch.read_retrieve
        end

        it "should loop when the cert request raises an Error" do
            @caclient.stubs(:request_cert).times(2).raises(StandardError, 'Testing').then.returns(true)
            ch = cert_handler.new(1,false)
            ch.expects(:sleep)
            ch.expects(:read_new_cert).returns(true)
            ch.read_retrieve
        end
        
        it "should loop when the new cert can't be read" do
            @caclient.stubs(:request_cert).returns(true)
            ch = cert_handler.new(1,false)
            ch.expects(:sleep)
            ch.expects(:read_new_cert).times(2).returns(false).then.returns(true)
            ch.read_retrieve
        end
    end

    describe "when in one time mode" do
        it "should exit if the cert request does not return a certificate" do
            @caclient.stubs(:request_cert).returns(false)
            ch = cert_handler.new(1,true)
            ch.expects(:exit).with(1).raises(SystemExit)
            lambda { ch.read_retrieve }.should raise_error(SystemExit)
        end


        it "should exit if the cert request raises an exception" do
            @caclient.stubs(:request_cert).raises(StandardError, 'Testing')
            ch = cert_handler.new(1,true)
            ch.expects(:exit).with(23).raises(SystemExit)
            lambda { ch.read_retrieve }.should raise_error(SystemExit)
        end
        
        it "should exit if the new cert can't be read" do
            @caclient.stubs(:request_cert).returns(true)
            Puppet::Network::HttpPool.stubs(:read_cert).returns(false)
            ch = cert_handler.new(1,true)
            ch.expects(:exit).with(34).raises(SystemExit)
            lambda { ch.read_retrieve }.should raise_error(SystemExit)
        end
    end
end
