#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/key'

describe Puppet::SSL::Key do
    before do
        @class = Puppet::SSL::Key
    end
    it "should be extended with the Indirector module" do
        @class.metaclass.should be_include(Puppet::Indirector)
    end

    it "should indirect key" do
        @class.indirection.name.should == :key
    end

    describe "when managing instances" do
        before do
            @key = @class.new("myname")
        end

        it "should have a name attribute" do
            @key.name.should == "myname"
        end

        it "should have a content attribute" do
            @key.should respond_to(:content)
        end

        it "should be able to read keys from disk" do
            path = "/my/path"
            File.expects(:read).with(path).returns("my key")
            key = mock 'key'
            OpenSSL::PKey::RSA.expects(:new).with("my key").returns(key)
            @key.read(path).should equal(key)
            @key.content.should equal(key)
        end

        it "should return an empty string when converted to a string with no key" do
            @key.to_s.should == ""
        end

        it "should convert the key to pem format when converted to a string" do
            key = mock 'key', :to_pem => "pem"
            @key.content = key
            @key.to_s.should == "pem"
        end
    end

    describe "when generating the private key" do
        before do
            @instance = @class.new("test")

            @key = mock 'key'
        end

        it "should create an instance of OpenSSL::PKey::RSA" do
            OpenSSL::PKey::RSA.expects(:new).returns(@key)

            @instance.generate
        end

        it "should create the private key with the keylength specified in the settings" do
            Puppet.settings.expects(:value).with(:keylength).returns(50)
            OpenSSL::PKey::RSA.expects(:new).with(50).returns(@key)

            @instance.generate
        end

        it "should set the content to the generated key" do
            OpenSSL::PKey::RSA.stubs(:new).returns(@key)
            @instance.generate
            @instance.content.should equal(@key)
        end

        it "should return the generated key" do
            OpenSSL::PKey::RSA.stubs(:new).returns(@key)
            @instance.generate.should equal(@key)
        end
    end
end
