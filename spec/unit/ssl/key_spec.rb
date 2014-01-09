#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/key'

describe Puppet::SSL::Key do
  before do
    @class = Puppet::SSL::Key
  end

  it "should be extended with the Indirector module" do
    @class.singleton_class.should be_include(Puppet::Indirector)
  end

  it "should indirect key" do
    @class.indirection.name.should == :key
  end

  it "should only support the text format" do
    @class.supported_formats.should == [:s]
  end

  it "should have a method for determining whether it's a CA key" do
    @class.new("test").should respond_to(:ca?)
  end

  it "should consider itself a ca key if its name matches the CA_NAME" do
    @class.new(Puppet::SSL::Host.ca_name).should be_ca
  end

  describe "when initializing" do
    it "should set its password file to the :capass if it's a CA key" do
      Puppet[:capass] = File.expand_path("/ca/pass")

      key = Puppet::SSL::Key.new(Puppet::SSL::Host.ca_name)
      key.password_file.should == Puppet[:capass]
    end

    it "should downcase its name" do
      @class.new("MyName").name.should == "myname"
    end

    it "should set its password file to the default password file if it is not the CA key" do
      Puppet[:passfile] = File.expand_path("/normal/pass")

      key = Puppet::SSL::Key.new("notca")
      key.password_file.should == Puppet[:passfile]
    end
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
      OpenSSL::PKey::RSA.expects(:new).returns(key)
      @key.read(path).should equal(key)
      @key.content.should equal(key)
    end

    it "should not try to use the provided password file if the file does not exist" do
      Puppet::FileSystem.stubs(:exist?).returns false
      @key.password_file = "/path/to/password"

      path = "/my/path"

      File.stubs(:read).with(path).returns("my key")
      OpenSSL::PKey::RSA.expects(:new).with("my key", nil).returns(mock('key'))
      File.expects(:read).with("/path/to/password").never

      @key.read(path)
    end

    it "should read the key with the password retrieved from the password file if one is provided" do
      Puppet::FileSystem.stubs(:exist?).returns true
      @key.password_file = "/path/to/password"

      path = "/my/path"
      File.expects(:read).with(path).returns("my key")
      File.expects(:read).with("/path/to/password").returns("my password")

      key = mock 'key'
      OpenSSL::PKey::RSA.expects(:new).with("my key", "my password").returns(key)
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

    it "should have a :to_text method that it delegates to the actual key" do
      real_key = mock 'key'
      real_key.expects(:to_text).returns "keytext"
      @key.content = real_key
      @key.to_text.should == "keytext"
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
      Puppet[:keylength] = "50"
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

    it "should return the key in pem format" do
      @instance.generate
      @instance.content.expects(:to_pem).returns "my normal key"
      @instance.to_s.should == "my normal key"
    end

    describe "with a password file set" do
      it "should return a nil password if the password file does not exist" do
        Puppet::FileSystem.expects(:exist?).with("/path/to/pass").returns false
        File.expects(:read).with("/path/to/pass").never

        @instance.password_file = "/path/to/pass"

        @instance.password.should be_nil
      end

      it "should return the contents of the password file as its password" do
        Puppet::FileSystem.expects(:exist?).with("/path/to/pass").returns true
        File.expects(:read).with("/path/to/pass").returns "my password"

        @instance.password_file = "/path/to/pass"

        @instance.password.should == "my password"
      end

      it "should export the private key to text using the password" do
        Puppet[:keylength] = "50"

        @instance.password_file = "/path/to/pass"
        @instance.stubs(:password).returns "my password"

        OpenSSL::PKey::RSA.expects(:new).returns(@key)
        @instance.generate

        cipher = mock 'cipher'
        OpenSSL::Cipher::DES.expects(:new).with(:EDE3, :CBC).returns cipher
        @key.expects(:export).with(cipher, "my password").returns "my encrypted key"

        @instance.to_s.should == "my encrypted key"
      end
    end
  end
end
