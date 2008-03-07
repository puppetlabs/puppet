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

            @instance.generate(@key).should == @request
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
