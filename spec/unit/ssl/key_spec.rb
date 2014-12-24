#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/key'

describe Puppet::SSL::Key do
  before do
    @class = Puppet::SSL::Key
  end

  it "should be extended with the Indirector module" do
    expect(@class.singleton_class).to be_include(Puppet::Indirector)
  end

  it "should indirect key" do
    expect(@class.indirection.name).to eq(:key)
  end

  it "should only support the text format" do
    expect(@class.supported_formats).to eq([:s])
  end

  it "should have a method for determining whether it's a CA key" do
    expect(@class.new("test")).to respond_to(:ca?)
  end

  it "should consider itself a ca key if its name matches the CA_NAME" do
    expect(@class.new(Puppet::SSL::Host.ca_name)).to be_ca
  end

  describe "when initializing" do
    it "should set its password file to the :capass if it's a CA key" do
      Puppet[:capass] = File.expand_path("/ca/pass")

      key = Puppet::SSL::Key.new(Puppet::SSL::Host.ca_name)
      expect(key.password_file).to eq(Puppet[:capass])
    end

    it "should downcase its name" do
      expect(@class.new("MyName").name).to eq("myname")
    end

    it "should set its password file to the default password file if it is not the CA key" do
      Puppet[:passfile] = File.expand_path("/normal/pass")

      key = Puppet::SSL::Key.new("notca")
      expect(key.password_file).to eq(Puppet[:passfile])
    end
  end

  describe "when managing instances" do
    before do
      @key = @class.new("myname")
    end

    it "should have a name attribute" do
      expect(@key.name).to eq("myname")
    end

    it "should have a content attribute" do
      expect(@key).to respond_to(:content)
    end

    it "should be able to read keys from disk" do
      path = "/my/path"
      File.expects(:read).with(path).returns("my key")
      key = mock 'key'
      OpenSSL::PKey::RSA.expects(:new).returns(key)
      expect(@key.read(path)).to equal(key)
      expect(@key.content).to equal(key)
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
      expect(@key.read(path)).to equal(key)
      expect(@key.content).to equal(key)
    end

    it "should return an empty string when converted to a string with no key" do
      expect(@key.to_s).to eq("")
    end

    it "should convert the key to pem format when converted to a string" do
      key = mock 'key', :to_pem => "pem"
      @key.content = key
      expect(@key.to_s).to eq("pem")
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_key = mock 'key'
      real_key.expects(:to_text).returns "keytext"
      @key.content = real_key
      expect(@key.to_text).to eq("keytext")
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
      expect(@instance.content).to equal(@key)
    end

    it "should return the generated key" do
      OpenSSL::PKey::RSA.stubs(:new).returns(@key)
      expect(@instance.generate).to equal(@key)
    end

    it "should return the key in pem format" do
      @instance.generate
      @instance.content.expects(:to_pem).returns "my normal key"
      expect(@instance.to_s).to eq("my normal key")
    end

    describe "with a password file set" do
      it "should return a nil password if the password file does not exist" do
        Puppet::FileSystem.expects(:exist?).with("/path/to/pass").returns false
        File.expects(:read).with("/path/to/pass").never

        @instance.password_file = "/path/to/pass"

        expect(@instance.password).to be_nil
      end

      it "should return the contents of the password file as its password" do
        Puppet::FileSystem.expects(:exist?).with("/path/to/pass").returns true
        File.expects(:read).with("/path/to/pass").returns "my password"

        @instance.password_file = "/path/to/pass"

        expect(@instance.password).to eq("my password")
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

        expect(@instance.to_s).to eq("my encrypted key")
      end
    end
  end
end
