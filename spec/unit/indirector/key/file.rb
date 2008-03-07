#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-7.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/key/file'

describe Puppet::SSL::Key::File do
    it "should be a subclass of the File terminus class" do
        Puppet::SSL::Key::File.superclass.should equal(Puppet::Indirector::File)
    end
    
    it "should have documentation" do
        Puppet::SSL::Key::File.doc.should be_instance_of(String)
    end

    describe "when managing keys on disk" do
        before do
            @file = Puppet::SSL::Key::File.new
        end

        describe "and choosing the location" do
            describe "for certificate authority keys" do
                before do
                    @private_key = "/path/to/private/ca/key"
                    @public_key = "/path/to/public/ca/key"
                    Puppet.settings.stubs(:value).with(:cakey).returns @private_key
                    Puppet.settings.stubs(:value).with(:capub).returns @public_key
                end

                it "should use the :cakey as the private key location and :capub for the public key location" do
                    File.expects(:open).with(@private_key, "w")
                    File.expects(:open).with(@private_key, "w")

                    key = stub 'key', :name => :ca

                    @file.save(key)
                end
            end

            describe "for normal keys" do
                before do
                    @name = "myhost"
                end

                it "should save private key to the :privatekeydir with the file named after the key name plus '.pem'"

                it "should save the public key to the :publickeydir with the file named after the key name plus '.pem'"
            end
        end

        it "should be able to find keys saved to disk"

        it "should convert found keys to instances of OpenSSL::PKey::RSA"

        it "should be able to save keys to disk"

        it "should save keys in pem format"

        it "should save both public and private keys"

        it "should be able to remove keys stored on disk"

        it "should remove both public and private keys when the key is destroyed"

        it "should fail when attempting to remove missing keys"
    end

    describe "when choosing a path for a ca key" do

        it "should use the cadir" do
            pending "eh"
            Puppet.settings.stubs(:value).with(:cadir).returns("/dir")
            @file.path(@name).should =~ /^\/dir/
        end

        it "should use 'ca_key.pem' as the file name" do
            pending "eh"
            @file.path(@name).should =~ /ca_key\.pem$/
        end
    end

    describe "when choosing a path for a non-ca key" do
        before do
            @name = :publickey
        end

        it "should use the privatekeydir" do
            pending "eh"
            Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
            @file.path(@name).should =~ /^\/dir/
        end

        it "should use the key name with the pem file extension" do
            pending "eh"
            @file.path(@name).should =~ /#{@name}\.pem$/
        end
    end

    describe "when saving" do
        before do
            Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
            @key = stub "key", :name => "foo"
        end

        it "should store the private key to disk in pem format in the privatekey directory" do
            pending "eh"
            @key.expects(:to_pem).returns(:data)
            @path = "/dir/foo.pem"
            filehandle = mock "filehandle"
            File.expects(:open).with(@path, "w").yields(filehandle)
            filehandle.expects(:print).with(:data)
            @file.save(@key)
        end

        it "should store the public key to disk in pem format in the publickey directory"
    end

    describe "when finding a key by name" do
        before do
            Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
            @name = "foo"
        end

        it "should return the key as a key object on success" do
            pending "eh"
            @path = "/dir/foo.pem"
            FileTest.stubs(:exists?).with(@path).returns(true)
            File.stubs(:read).with(@path).returns(:data)
            OpenSSL::PKey::RSA.expects(:new).with(:data).returns(:mykey)
            @file.find(@name).should == :mykey
        end

        it "should return 'nil' on failure" do
            pending "eh"
            @path = "/dir/foo.pem"
            FileTest.stubs(:exists?).with(@path).returns(false)
            @file.find(@name).should == nil
        end
    end

    describe "when removing a key" do
        before do
            Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
            @name = "foo"
        end

        it "should remove the key from disk and return true" do
            pending "eh"
            @path = "/dir/foo.pem"
            FileTest.stubs(:exists?).with(@path).returns(true)
            File.stubs(:unlink).with(@path).returns(true)
            @file.destroy(@name).should == true
        end

        it "should return an exception on failure" do
            pending "eh"
            @path = "/dir/foo.pem"
            FileTest.stubs(:exists?).with(@path).returns(false)
            @file.destroy(@name).should == nil
        end
    end
end
