#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-7.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/certificate/file'

describe Puppet::SSL::Certificate::File do
    before do
        @file = Puppet::SSL::Certificate::File.new
        @cert = Puppet::SSL::Certificate.new("myname")
        Puppet.settings.stubs(:value).with(@file.class.directory_setting).returns "/test/dir"
        @path = "/test/dir/myname.pem"
    end

    it "should have documentation" do
        Puppet::SSL::Certificate::File.doc.should be_instance_of(String)
    end
    
    describe "when choosing the location for certificates" do
        it "should set them in the :certdir, with the certificate name plus '.pem'" do
            @file.path(@cert.name).should == @path
        end
    end

    describe "when finding certificates on disk" do
        describe "and no certificate is present" do
            before do
                FileTest.expects(:exist?).with(@path).returns false
            end

            it "should return nil" do
                @file.find(@cert.name).should be_nil
            end
        end

        describe "and a certificate is present" do
            before do
                FileTest.expects(:exist?).with(@path).returns true
            end

            it "should return an instance of the model, which it should use to read the certificate" do
                cert = mock 'cert'
                Puppet::SSL::Certificate.expects(:new).with("myname").returns cert
                cert.expects(:read).with(@path)
                @file.find("myname").should equal(cert)
            end
        end
    end

    describe "when saving certificates to disk" do
        it "should fail if the directory is absent" do
            FileTest.expects(:directory?).with(File.dirname(@path)).returns false
            lambda { @file.save(@cert) }.should raise_error(Puppet::Error)
        end

        it "should fail if the directory is not writeable" do
            FileTest.stubs(:directory?).returns true
            FileTest.expects(:writable?).with(File.dirname(@path)).returns false
            lambda { @file.save(@cert) }.should raise_error(Puppet::Error)
        end

        it "should save to the path the output of converting the certificate to a string" do
            FileTest.stubs(:directory?).returns true
            FileTest.stubs(:writable?).returns true

            fh = mock 'filehandle'
            File.expects(:open).with(@path, "w").yields(fh)

            @cert.expects(:to_s).returns "mycert"

            fh.expects(:print).with("mycert")

            @file.save(@cert)

        end
    end

    describe "when destroying certificates" do
        describe "that do not exist" do
            before do
                FileTest.expects(:exist?).with(@path).returns false
            end

            it "should fail" do
                lambda { @file.destroy(@cert) }.should raise_error(Puppet::Error)
            end
        end

        describe "that exist" do
            before do
                FileTest.expects(:exist?).with(@path).returns true
            end

            it "should unlink the certificate file" do
                File.expects(:unlink).with(@path)
                @file.destroy(@cert)
            end
        end
    end
end
