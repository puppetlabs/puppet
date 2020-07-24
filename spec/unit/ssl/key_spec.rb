require 'spec_helper'

require 'puppet/ssl/key'

describe Puppet::SSL::Key do
  before do
    @class = Puppet::SSL::Key
  end

  it "should only support the text format" do
    expect(@class.supported_formats).to eq([:s])
  end

  describe "when initializing" do
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
      expect(Puppet::FileSystem).to receive(:read).with(path, :encoding => Encoding::ASCII).and_return("my key")
      key = double('key')
      expect(OpenSSL::PKey::RSA).to receive(:new).and_return(key)
      expect(@key.read(path)).to equal(key)
      expect(@key.content).to equal(key)
    end

    it "should not try to use the provided password file if the file does not exist" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(false)
      @key.password_file = "/path/to/password"

      path = "/my/path"

      allow(Puppet::FileSystem).to receive(:read).with(path, :encoding => Encoding::ASCII).and_return("my key")
      expect(OpenSSL::PKey::RSA).to receive(:new).with("my key", nil).and_return(double('key'))
      expect(Puppet::FileSystem).not_to receive(:read).with("/path/to/password", :encoding => Encoding::BINARY)

      @key.read(path)
    end

    it "should read the key with the password retrieved from the password file if one is provided" do
      allow(Puppet::FileSystem).to receive(:exist?).and_return(true)
      @key.password_file = "/path/to/password"

      path = "/my/path"
      expect(Puppet::FileSystem).to receive(:read).with(path, :encoding => Encoding::ASCII).and_return("my key")
      expect(Puppet::FileSystem).to receive(:read).with("/path/to/password", :encoding => Encoding::BINARY).and_return("my password")

      key = double('key')
      expect(OpenSSL::PKey::RSA).to receive(:new).with("my key", "my password").and_return(key)
      expect(@key.read(path)).to equal(key)
      expect(@key.content).to equal(key)
    end

    it "should return an empty string when converted to a string with no key" do
      expect(@key.to_s).to eq("")
    end

    it "should convert the key to pem format when converted to a string" do
      key = double('key', :to_pem => "pem")
      @key.content = key
      expect(@key.to_s).to eq("pem")
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_key = double('key')
      expect(real_key).to receive(:to_text).and_return("keytext")
      @key.content = real_key
      expect(@key.to_text).to eq("keytext")
    end
  end

  describe "when generating the private key" do
    before do
      @instance = @class.new("test")

      @key = double('key')
    end

    it "should create an instance of OpenSSL::PKey::RSA" do
      expect(OpenSSL::PKey::RSA).to receive(:new).and_return(@key)

      @instance.generate
    end

    it "should create the private key with the keylength specified in the settings" do
      Puppet[:keylength] = 513
      expect(OpenSSL::PKey::RSA).to receive(:new).with(513).and_return(@key)

      @instance.generate
    end

    it "should set the content to the generated key" do
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(@key)
      @instance.generate
      expect(@instance.content).to equal(@key)
    end

    it "should return the generated key" do
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(@key)
      expect(@instance.generate).to equal(@key)
    end

    it "should return the key in pem format" do
      @instance.generate
      expect(@instance.content).to receive(:to_pem).and_return("my normal key")
      expect(@instance.to_s).to eq("my normal key")
    end

    describe "with a password file set" do
      it "should return a nil password if the password file does not exist" do
        expect(Puppet::FileSystem).to receive(:exist?).with("/path/to/pass").and_return(false)
        expect(Puppet::FileSystem).not_to receive(:read).with("/path/to/pass", :encoding => Encoding::BINARY)

        @instance.password_file = "/path/to/pass"

        expect(@instance.password).to be_nil
      end

      it "should return the contents of the password file as its password" do
        expect(Puppet::FileSystem).to receive(:exist?).with("/path/to/pass").and_return(true)
        expect(Puppet::FileSystem).to receive(:read).with("/path/to/pass", :encoding => Encoding::BINARY).and_return("my password")

        @instance.password_file = "/path/to/pass"

        expect(@instance.password).to eq("my password")
      end

      it "should export the private key to text using the password" do
        @instance.password_file = "/path/to/pass"
        allow(@instance).to receive(:password).and_return("my password")

        expect(OpenSSL::PKey::RSA).to receive(:new).and_return(@key)
        @instance.generate

        cipher = double('cipher')
        expect(OpenSSL::Cipher::DES).to receive(:new).with(:EDE3, :CBC).and_return(cipher)
        expect(@key).to receive(:export).with(cipher, "my password").and_return("my encrypted key")

        expect(@instance.to_s).to eq("my encrypted key")
      end
    end
  end
end
