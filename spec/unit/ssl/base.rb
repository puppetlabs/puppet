#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate'

class TestCertificate < Puppet::SSL::Base; end

describe Puppet::SSL::Certificate do
    before :each do
        @base = TestCertificate.new("name")
    end

    describe "when fingerprinting content" do
        before :each do
            @cert = stub 'cert', :to_der => "DER"
            @base.stubs(:content).returns(@cert)
            OpenSSL::Digest.stubs(:constants).returns ["MD5", "DIGEST"]
        end

        it "should digest the certificate DER value and return a ':' seperated nibblet string" do
            @cert.expects(:to_der).returns("DER")
            OpenSSL::Digest.expects(:hexdigest).with("MD5", "DER").returns "digest"

            @base.fingerprint.should == "DI:GE:ST"
        end

        it "should raise an error if the digest algorithm is not defined" do
            OpenSSL::Digest.expects(:constants).returns []

            lambda { @base.fingerprint }.should raise_error
        end

        it "should use the given digest algorithm" do
            OpenSSL::Digest.expects(:hexdigest).with("DIGEST", "DER").returns "digest"

            @base.fingerprint(:digest).should == "DI:GE:ST"
        end
    end
end