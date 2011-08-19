#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/key/file'

describe Puppet::SSL::Key::File do
  it "should have documentation" do
    Puppet::SSL::Key::File.doc.should be_instance_of(String)
  end

  it "should use the :privatekeydir as the collection directory" do
    Puppet.settings.expects(:value).with(:privatekeydir).returns "/key/dir"
    Puppet::SSL::Key::File.collection_directory.should == "/key/dir"
  end

  it "should store the ca key at the :cakey location" do
    Puppet.settings.stubs(:use)
    Puppet.settings.stubs(:value).returns "whatever"
    Puppet.settings.stubs(:value).with(:cakey).returns "/ca/key"
    file = Puppet::SSL::Key::File.new
    file.stubs(:ca?).returns true
    file.path("whatever").should == "/ca/key"
  end

  describe "when choosing the path for the public key" do
    it "should use the :capub setting location if the key is for the certificate authority" do
      Puppet.settings.stubs(:value).returns "/fake/dir"
      Puppet.settings.stubs(:value).with(:capub).returns "/ca/pubkey"
      Puppet.settings.stubs(:use)

      @searcher = Puppet::SSL::Key::File.new
      @searcher.stubs(:ca?).returns true
      @searcher.public_key_path("whatever").should == "/ca/pubkey"
    end

    it "should use the host name plus '.pem' in :publickeydir for normal hosts" do
      Puppet.settings.stubs(:value).with(:privatekeydir).returns "/private/key/dir"
      Puppet.settings.stubs(:value).with(:publickeydir).returns "/public/key/dir"
      Puppet.settings.stubs(:use)

      @searcher = Puppet::SSL::Key::File.new
      @searcher.stubs(:ca?).returns false
      @searcher.public_key_path("whatever").should == "/public/key/dir/whatever.pem"
    end
  end

  describe "when managing private keys" do
    before do
      @searcher = Puppet::SSL::Key::File.new

      @private_key_path = File.join("/fake/key/path")
      @public_key_path = File.join("/other/fake/key/path")

      @searcher.stubs(:public_key_path).returns @public_key_path
      @searcher.stubs(:path).returns @private_key_path

      FileTest.stubs(:directory?).returns true
      FileTest.stubs(:writable?).returns true

      @public_key = stub 'public_key'
      @real_key = stub 'sslkey', :public_key => @public_key

      @key = stub 'key', :name => "myname", :content => @real_key

      @request = stub 'request', :key => "myname", :instance => @key
    end

    it "should save the public key when saving the private key" do
      Puppet.settings.stubs(:writesub)

      fh = mock 'filehandle'

      Puppet.settings.expects(:writesub).with(:publickeydir, @public_key_path).yields fh
      @public_key.expects(:to_pem).returns "my pem"

      fh.expects(:print).with "my pem"

      @searcher.save(@request)
    end

    it "should destroy the public key when destroying the private key" do
      File.stubs(:unlink).with(@private_key_path)
      FileTest.stubs(:exist?).with(@private_key_path).returns true
      FileTest.expects(:exist?).with(@public_key_path).returns true
      File.expects(:unlink).with(@public_key_path)

      @searcher.destroy(@request)
    end

    it "should not fail if the public key does not exist when deleting the private key" do
      File.stubs(:unlink).with(@private_key_path)

      FileTest.stubs(:exist?).with(@private_key_path).returns true
      FileTest.expects(:exist?).with(@public_key_path).returns false
      File.expects(:unlink).with(@public_key_path).never

      @searcher.destroy(@request)
    end
  end
end
