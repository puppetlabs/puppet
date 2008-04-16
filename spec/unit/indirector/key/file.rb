#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-7.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/key/file'

describe Puppet::SSL::Key::File do
    it "should have documentation" do
        Puppet::SSL::Key::File.doc.should be_instance_of(String)
    end

    it "should use the :privatekeydir as the collection directory" do
        Puppet.settings.expects(:value).with(:privatekeydir).returns "/key/dir"
        Puppet::SSL::Key::File.collection_directory.should == "/key/dir"
    end

    describe "when managing private keys" do
        before do
            @private = "/private/key/dir"
            @public = "/public/key/dir"
            Puppet.settings.stubs(:value).with(:privatekeydir).returns @private
            Puppet.settings.stubs(:value).with(:publickeydir).returns @public
            Puppet.settings.stubs(:use)

            @searcher = Puppet::SSL::Key::File.new

            @privatekey = File.join(@private, "myname" + ".pem")
            @publickey = File.join(@public, "myname" + ".pem")

            @public_key = stub 'public_key'
            @real_key = stub 'sslkey', :public_key => @public_key

            @key = stub 'key', :name => "myname", :content => @real_key

            @request = stub 'request', :key => "myname", :instance => @key
        end

        it "should save the public key when saving the private key" do
            FileTest.stubs(:directory?).returns true
            FileTest.stubs(:writable?).returns true

            File.stubs(:open).with(@privatekey, "w")

            fh = mock 'filehandle'

            File.expects(:open).with(@publickey, "w").yields fh
            @public_key.expects(:to_pem).returns "my pem"

            fh.expects(:print).with "my pem"

            @searcher.save(@request)
        end

        it "should destroy the public key when destroying the private key" do
            File.stubs(:unlink).with(@privatekey)
            FileTest.stubs(:exist?).with(@privatekey).returns true
            FileTest.expects(:exist?).with(@publickey).returns true
            File.expects(:unlink).with(@publickey)

            @searcher.destroy(@request)
        end

        it "should not fail if the public key does not exist when deleting the private key" do
            File.stubs(:unlink).with(@privatekey)

            FileTest.stubs(:exist?).with(@privatekey).returns true
            FileTest.expects(:exist?).with(@publickey).returns false
            File.expects(:unlink).with(@publickey).never

            @searcher.destroy(@request)
        end
    end
end
