#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-22.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/sslcertificates/monkey_patch'
require 'puppet/indirector/ssl_rsa/file'


describe Puppet::Indirector::SslRsa::File do

    it "should be a subclass of the File terminus class" do
        Puppet::Indirector::SslRsa::File.superclass.should equal(Puppet::Indirector::File)
    end
    
    it "should have documentation" do
        Puppet::Indirector::SslRsa::File.doc.should be_instance_of(String)
    end
end

describe Puppet::Indirector::SslRsa::File, " when choosing a path for a ca key" do
    before do
        Puppet.settings.stubs(:use)
        @file = Puppet::Indirector::SslRsa::File.new
        @name = :ca
    end

    it "should use the cadir" do
        Puppet.settings.stubs(:value).with(:cadir).returns("/dir")
        @file.path(@name).should =~ /^\/dir/
    end

    it "should use 'ca_key.pem' as the file name" do
        @file.path(@name).should =~ /ca_key\.pem$/
    end
end

describe Puppet::Indirector::SslRsa::File, " when choosing a path for a non-ca key" do
    before do
        Puppet.settings.stubs(:use)
        @file = Puppet::Indirector::SslRsa::File.new
        @name = :publickey
    end

    it "should use the publickeydir" do
        Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
        @file.path(@name).should =~ /^\/dir/
    end

    it "should use the key name with the pem file extension" do
        @file.path(@name).should =~ /#{@name}\.pem$/
    end
end

describe Puppet::Indirector::SslRsa::File, " when saving" do
    before do
        Puppet.settings.stubs(:use)
        @file = Puppet::Indirector::SslRsa::File.new

        Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
        @key = stub "key", :name => "foo"
    end

    it "should store the rsa key to disk in pem format" do
        @key.expects(:to_pem).returns(:data)
        @path = "/dir/foo.pem"
        filehandle = mock "filehandle"
        File.expects(:open).with(@path, "w").yields(filehandle)
        filehandle.expects(:print).with(:data)
        @file.save(@key)
    end
end

describe Puppet::Indirector::SslRsa::File, " when finding a key by name" do
    before do
        Puppet.settings.stubs(:use)
        @file = Puppet::Indirector::SslRsa::File.new

        Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
        @name = "foo"
    end

    it "should return the key as a key object on success" do
        @path = "/dir/foo.pem"
        FileTest.stubs(:exists?).with(@path).returns(true)
        File.stubs(:read).with(@path).returns(:data)
        OpenSSL::PKey::RSA.expects(:new).with(:data).returns(:mykey)
        @file.find(@name).should == :mykey
    end

    it "should return 'nil' on failure" do
        @path = "/dir/foo.pem"
        FileTest.stubs(:exists?).with(@path).returns(false)
        @file.find(@name).should == nil
    end
end

describe Puppet::Indirector::SslRsa::File, " when removing a key" do
    before do
        Puppet.settings.stubs(:use)
        @file = Puppet::Indirector::SslRsa::File.new

        Puppet.settings.stubs(:value).with(:publickeydir).returns("/dir")
        @name = "foo"
    end

    it "should remove the key from disk and return true" do
        @path = "/dir/foo.pem"
        FileTest.stubs(:exists?).with(@path).returns(true)
        File.stubs(:unlink).with(@path).returns(true)
        @file.destroy(@name).should == true
    end

    it "should return an exception on failure" do
        @path = "/dir/foo.pem"
        FileTest.stubs(:exists?).with(@path).returns(false)
        @file.destroy(@name).should == nil
    end
end
