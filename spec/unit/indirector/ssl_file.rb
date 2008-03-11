#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-10.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/ssl_file'

describe Puppet::Indirector::SslFile do
    before do
        @indirection = stub 'indirection', :name => :testing
        Puppet::Indirector::Indirection.expects(:instance).with(:testing).returns(@indirection)
        @file_class = Class.new(Puppet::Indirector::SslFile) do
            def self.to_s
                "Testing::Mytype"
            end
        end

        @setting = :mydir
        @file_class.store_in @setting
        @path = "/my/directory"
        Puppet.settings.stubs(:[]).with(@setting).returns(@path)
    end

    it "should use ssl upon initialization" do
        Puppet.settings.expects(:use).with(:ssl)
        @file_class.new
    end

    it "should fail if no store directory has been set" do
        @file_class.store_in nil
        lambda { @file_class.collection_directory }.should raise_error(Puppet::DevError)
    end

    describe "when managing ssl files" do
        before do
            Puppet.settings.stubs(:use)
            @searcher = @file_class.new

            @cert = stub 'certificate', :name => "myname"
            @certpath = File.join(@path, "myname" + ".pem")
        end
        
        describe "when choosing the location for certificates" do
            it "should set them in the setting directory, with the certificate name plus '.pem'" do
                @searcher.path(@cert.name).should == @certpath
            end
        end

        describe "when finding certificates on disk" do
            describe "and no certificate is present" do
                before do
                    FileTest.expects(:exist?).with(@certpath).returns false
                end

                it "should return nil" do
                    @searcher.find(@cert.name).should be_nil
                end
            end

            describe "and a certificate is present" do
                before do
                    FileTest.expects(:exist?).with(@certpath).returns true
                end

                it "should return an instance of the model, which it should use to read the certificate" do
                    cert = mock 'cert'
                    model = mock 'model'
                    @file_class.stubs(:model).returns model

                    model.expects(:new).with("myname").returns cert
                    cert.expects(:read).with(@certpath)
                    @searcher.find("myname").should equal(cert)
                end
            end
        end

        describe "when saving certificates to disk" do
            it "should fail if the directory is absent" do
                FileTest.expects(:directory?).with(File.dirname(@certpath)).returns false
                lambda { @searcher.save(@cert) }.should raise_error(Puppet::Error)
            end

            it "should fail if the directory is not writeable" do
                FileTest.stubs(:directory?).returns true
                FileTest.expects(:writable?).with(File.dirname(@certpath)).returns false
                lambda { @searcher.save(@cert) }.should raise_error(Puppet::Error)
            end

            it "should save to the path the output of converting the certificate to a string" do
                FileTest.stubs(:directory?).returns true
                FileTest.stubs(:writable?).returns true

                fh = mock 'filehandle'
                File.expects(:open).with(@certpath, "w").yields(fh)

                @cert.expects(:to_s).returns "mycert"

                fh.expects(:print).with("mycert")

                @searcher.save(@cert)

            end
        end

        describe "when destroying certificates" do
            describe "that do not exist" do
                before do
                    FileTest.expects(:exist?).with(@certpath).returns false
                end

                it "should fail" do
                    lambda { @searcher.destroy(@cert) }.should raise_error(Puppet::Error)
                end
            end

            describe "that exist" do
                before do
                    FileTest.expects(:exist?).with(@certpath).returns true
                end

                it "should unlink the certificate file" do
                    File.expects(:unlink).with(@certpath)
                    @searcher.destroy(@cert)
                end
            end
        end
    end
end
