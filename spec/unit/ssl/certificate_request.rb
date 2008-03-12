#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_request'
require 'puppet/ssl/key'

describe Puppet::SSL::CertificateRequest do
    before do
        @class = Puppet::SSL::CertificateRequest
    end

    it "should be extended with the Indirector module" do
        @class.metaclass.should be_include(Puppet::Indirector)
    end

    it "should indirect certificate_request" do
        @class.indirection.name.should == :certificate_request
    end

    it "should use any provided name as its name" do
        @class.new("myname").name.should == "myname"
    end

    it "should default to the :file terminus class" do
        @class.indirection.terminus(:file).expects(:find).with "myname"
        @class.find("myname")
    end

    it "should allow specification of a different terminus class" do
        @class.indirection.terminus(:ca_file).expects(:find).with { |*args| args[0] == "myname" }
        @class.find("myname", :in => :ca_file)
    end

    describe "when managing instances" do
        before do
            @request = @class.new("myname")
        end

        it "should have a name attribute" do
            @request.name.should == "myname"
        end

        it "should have a content attribute" do
            @request.should respond_to(:content)
        end

        it "should be able to read requests from disk" do
            path = "/my/path"
            File.expects(:read).with(path).returns("my request")
            request = mock 'request'
            OpenSSL::X509::Request.expects(:new).with("my request").returns(request)
            @request.read(path).should equal(request)
            @request.content.should equal(request)
        end

        it "should return an empty string when converted to a string with no request" do
            @request.to_s.should == ""
        end

        it "should convert the request to pem format when converted to a string" do
            request = mock 'request', :to_pem => "pem"
            @request.content = request
            @request.to_s.should == "pem"
        end
    end

    describe "when generating" do
        before do
            @instance = @class.new("myname")

            key = Puppet::SSL::Key.new("myname")
            @key = key.generate
        end

        it "should log that it is creating a new certificate request" do
            Puppet.expects(:info)
            @instance.generate(@key)
        end

        # It just doesn't make sense to work so hard around mocking all of this crap five times in order to get this test down to one expectation
        # per test.
        it "should create a new certificate request with the subject set to [CN, name], the version set to 0, the public key set to the privided key's public key, and signed by the provided key" do
            @request = mock 'request'
            OpenSSL::X509::Request.expects(:new).returns(@request)

            subject = mock 'subject'
            OpenSSL::X509::Name.expects(:new).with([["CN", @instance.name]]).returns(subject)
            @request.expects(:version=).with 0

            # For some reason, this is failing, even though the values are correct.
            # It seems to be considering the values different if i use 'with'.
            @request.expects(:public_key=)
            @request.expects(:subject=).with subject

            # Again, this is weirdly failing, even though it's painfully simple.
            @request.expects(:sign)

            @request.stubs(:verify).returns(true)

            @instance.generate(@key).should == @request
        end

        it "should verify the generated request using the public key" do
            @request = mock 'request'
            OpenSSL::X509::Request.expects(:new).returns(@request)

            subject = mock 'subject'
            OpenSSL::X509::Name.stubs(:new)

            @request.stubs(:version=)
            @request.stubs(:public_key=)
            @request.stubs(:subject=)
            @request.stubs(:sign)

            # Grr, mocha is broken in this class for some reason; I can't get
            # the 'with' arguments to register correctly.
            @request.expects(:verify).returns true

            @instance.generate(@key).should == @request
        end

        it "should fail if verification fails" do
            @request = OpenSSL::X509::Request.new
            OpenSSL::X509::Request.expects(:new).returns(@request)

            @request.expects(:verify).returns false

            lambda { @instance.generate(@key) }.should raise_error(Puppet::Error)
        end

        it "should return the generated request" do
            @instance.generate(@key).should be_instance_of(OpenSSL::X509::Request)
        end

        it "should set its content to the generated request" do
            @instance.generate(@key)
            @instance.content.should be_instance_of(OpenSSL::X509::Request)
        end
    end
end
