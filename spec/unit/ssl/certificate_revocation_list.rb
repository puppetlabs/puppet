#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_revocation_list'

describe Puppet::SSL::CertificateRevocationList do
    before do
        @cert = stub 'cert', :subject => "mysubject"

        @key = stub 'key'

        @class = Puppet::SSL::CertificateRevocationList
    end

    describe "when an instance" do
        before do
            @class.any_instance.stubs(:read_or_generate)

            @crl = @class.new("myname", @cert, @key)
        end

        it "should have a name attribute" do
            @crl.name.should == "myname"
        end

        it "should have a content attribute" do
            @crl.should respond_to(:content)
        end

        it "should be able to read the crl from disk" do
            path = "/my/path"
            File.expects(:read).with(path).returns("my crl")
            crl = mock 'crl'
            OpenSSL::X509::CRL.expects(:new).with("my crl").returns(crl)
            @crl.read(path).should equal(crl)
            @crl.content.should equal(crl)
        end

        it "should return an empty string when converted to a string with no crl" do
            @crl.to_s.should == ""
        end

        it "should convert the crl to pem format when converted to a string" do
            crl = mock 'crl', :to_pem => "pem"
            @crl.content = crl
            @crl.to_s.should == "pem"
        end

        it "should have a :to_text method that it delegates to the actual crl" do
            real_crl = mock 'crl'
            real_crl.expects(:to_text).returns "crltext"
            @crl.content = real_crl
            @crl.to_text.should == "crltext"
        end
    end

    describe "when initializing" do
        it "should require the CA cert and key" do
            lambda { @class.new("myname") }.should raise_error(ArgumentError)
        end

        it "should fail if :cacrl is set to false" do
            Puppet.settings.expects(:value).with(:cacrl).returns false
            lambda { @class.new("myname", @cert, @key) }.should raise_error(Puppet::Error)
        end

        it "should fail if :cacrl is set to the string 'false'" do
            Puppet.settings.expects(:value).with(:cacrl).returns "false"
            lambda { @class.new("myname", @cert, @key) }.should raise_error(Puppet::Error)
        end

        it "should read the CRL from disk" do
            Puppet.settings.stubs(:value).with(:cacrl).returns "/path/to/crl"
            @class.any_instance.expects(:read).with("/path/to/crl").returns("my key")

            @class.new("myname", @cert, @key)
        end

        describe "and no CRL exists on disk" do
            before do
                @class.any_instance.stubs(:read).returns(false)
                @class.any_instance.stubs(:generate)
                @class.any_instance.stubs(:save)
            end

            it "should generate a new CRL" do
                @class.any_instance.expects(:generate).with(@cert, @key)

                @class.new("myname", @cert, @key)
            end

            it "should save the CRL" do
                @class.any_instance.expects(:save).with(@key)

                @class.new("myname", @cert, @key)
            end
        end
    end

    describe "when generating the crl" do
        before do
            @real_crl = mock 'crl'
            @real_crl.stub_everything

            OpenSSL::X509::CRL.stubs(:new).returns(@real_crl)

            @class.any_instance.stubs(:read_or_generate)

            @crl = @class.new("myname", @cert, @key)
        end

        it "should set its issuer to the subject of the passed certificate" do
            @real_crl.expects(:issuer=).with(@cert.subject)

            @crl.generate(@cert, @key)
        end

        it "should set its version to 1" do
            @real_crl.expects(:version=).with(1)

            @crl.generate(@cert, @key)
        end

        it "should create an instance of OpenSSL::X509::CRL" do
            OpenSSL::X509::CRL.expects(:new).returns(@real_crl)

            @crl.generate(@cert, @key)
        end

        it "should set the content to the generated crl" do
            @crl.generate(@cert, @key)
            @crl.content.should equal(@real_crl)
        end

        it "should return the generated crl" do
            @crl.generate(@cert, @key).should equal(@real_crl)
        end

        it "should return the crl in pem format" do
            @crl.generate(@cert, @key)
            @crl.content.expects(:to_pem).returns "my normal crl"
            @crl.to_s.should == "my normal crl"
        end
    end

    describe "when saving the CRL" do
        before do
            @class.any_instance.stubs(:read_or_generate)
            @class.wrapped_class.any_instance.stubs(:issuer=)

            @crl = @class.new("myname", @cert, @key)
            @crl.generate(@cert, @key)
        end

        it "should use the Settings#write method to write the file" do
            pending("Not fully ported") do
                fh = mock 'filehandle'
                Puppet.settings.expects(:write).with(:cacrl).yields fh

                fh.expects :print

                @crl.save(@key)
            end
        end
    end
end
