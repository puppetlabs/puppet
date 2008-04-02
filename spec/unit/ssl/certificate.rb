#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate'

describe Puppet::SSL::Certificate do
    before do
        @class = Puppet::SSL::Certificate
    end

    after do
        @class.instance_variable_set("@ca_location", nil)
    end

    it "should be extended with the Indirector module" do
        @class.metaclass.should be_include(Puppet::Indirector)
    end

    it "should indirect certificate" do
        @class.indirection.name.should == :certificate
    end

    it "should default to the :file terminus class" do
        @class.indirection.terminus(:file).expects(:find).with "myname"
        @class.find("myname")
    end

    it "should allow specification of a different terminus class" do
        @class.indirection.terminus(:ca_file).expects(:find).with { |*args| args[0] == "myname" }
        @class.find("myname", :in => :ca_file)
    end

    it "should default to a local certificate authority" do
        @class.ca_location.should == :local
    end

    it "should allow overriding the ca location" do
        @class.ca_is :remote
        @class.ca_location.should == :remote
    end

    describe "when managing instances" do
        before do
            @certificate = @class.new("myname")
        end

        it "should have a name attribute" do
            @certificate.name.should == "myname"
        end

        it "should have a content attribute" do
            @certificate.should respond_to(:content)
        end

        it "should be able to read certificates from disk" do
            path = "/my/path"
            File.expects(:read).with(path).returns("my certificate")
            certificate = mock 'certificate'
            OpenSSL::X509::Certificate.expects(:new).with("my certificate").returns(certificate)
            @certificate.read(path).should equal(certificate)
            @certificate.content.should equal(certificate)
        end

        it "should return an empty string when converted to a string with no certificate" do
            @certificate.to_s.should == ""
        end

        it "should convert the certificate to pem format when converted to a string" do
            certificate = mock 'certificate', :to_pem => "pem"
            @certificate.content = certificate
            @certificate.to_s.should == "pem"
        end

        it "should have a :to_text method that it delegates to the actual key" do
            real_certificate = mock 'certificate'
            real_certificate.expects(:to_text).returns "certificatetext"
            @certificate.content = real_certificate
            @certificate.to_text.should == "certificatetext"
        end
    end

    describe "when generating the certificate" do
        before do
            @cert = @class.new("test")
            @request = mock 'request'
        end

        describe "from a local ca" do
            before do
                @class.stubs(:ca_location).returns :local
            end

            it "should save the certificate request to and try to find the cert in the :ca_file terminus" do
                @request.expects(:save).with(:in => :ca_file)
                @cert.class.expects(:find).with("test", :in => :ca_file)

                @cert.generate(@request)
            end
        end

        describe "from a remote ca" do
            before do
                @class.stubs(:ca_location).returns :remote
            end

            it "should save the certificate request to and try to find the cert in the :rest terminus" do
                @request.expects(:save).with(:in => :rest)
                @cert.class.expects(:find).with("test", :in => :rest)

                @cert.generate(@request)
            end
        end

        describe "successfully" do
            it "should set its content to the content of the retrieved certificate" do
                @request.stubs(:save)
                newcert = mock 'newcert', :content => "realcert"
                @cert.class.expects(:find).returns(newcert)

                @cert.generate(@request)

                @cert.content.should == "realcert"
            end

            it "should return true" do
                @request.stubs(:save)
                newcert = mock 'newcert', :content => "realcert"
                @cert.class.expects(:find).returns(newcert)

                @cert.generate(@request).should be_true
            end
        end

        describe "unsuccessfully" do
            it "should return false" do
                @request.stubs(:save)
                @cert.class.expects(:find).returns(nil)

                @cert.generate(@request).should be_false
            end
        end
    end
end
