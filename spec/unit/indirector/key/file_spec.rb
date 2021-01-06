require 'spec_helper'

require 'puppet/indirector/key/file'

describe Puppet::SSL::Key::File do
  it "should have documentation" do
    expect(Puppet::SSL::Key::File.doc).to be_instance_of(String)
  end

  it "should use the :privatekeydir as the collection directory" do
    Puppet[:privatekeydir] = File.expand_path("/key/dir")
    expect(Puppet::SSL::Key::File.collection_directory).to eq(Puppet[:privatekeydir])
  end

  describe "when choosing the path for the public key" do
    it "should use the host name plus '.pem' in :publickeydir for normal hosts" do
      Puppet[:privatekeydir] = File.expand_path("/private/key/dir")
      Puppet[:publickeydir] = File.expand_path("/public/key/dir")
      allow(Puppet.settings).to receive(:use)

      @searcher = Puppet::SSL::Key::File.new
      expect(@searcher.public_key_path("whatever")).to eq(File.expand_path("/public/key/dir/whatever.pem"))
    end
  end

  describe "when managing private keys" do
    before do
      @searcher = Puppet::SSL::Key::File.new

      @private_key_path = File.join("/fake/key/path")
      @public_key_path = File.join("/other/fake/key/path")

      allow(@searcher).to receive(:public_key_path).and_return(@public_key_path)
      allow(@searcher).to receive(:path).and_return(@private_key_path)

      allow(FileTest).to receive(:directory?).and_return(true)
      allow(FileTest).to receive(:writable?).and_return(true)

      @public_key = double('public_key')
      @real_key = double('sslkey', :public_key => @public_key)

      @key = double('key', :name => "myname", :content => @real_key)

      @request = double('request', :key => "myname", :instance => @key)
    end

    it "should save the public key when saving the private key" do
      fh = StringIO.new

      expect(Puppet.settings.setting(:publickeydir)).to receive(:open_file).with(@public_key_path, 'w:ASCII').and_yield(fh)
      allow(Puppet.settings.setting(:privatekeydir)).to receive(:open_file)
      expect(@public_key).to receive(:to_pem).and_return("my pem")

      @searcher.save(@request)

      expect(fh.string).to eq("my pem")
    end

    it "should destroy the public key when destroying the private key" do
      expect(Puppet::FileSystem).to receive(:unlink).with(Puppet::FileSystem.pathname(@private_key_path))
      expect(Puppet::FileSystem).to receive(:exist?).with(Puppet::FileSystem.pathname(@private_key_path)).and_return(true)
      expect(Puppet::FileSystem).to receive(:exist?).with(Puppet::FileSystem.pathname(@public_key_path)).and_return(true)
      expect(Puppet::FileSystem).to receive(:unlink).with(Puppet::FileSystem.pathname(@public_key_path))

      @searcher.destroy(@request)
    end

    it "should not fail if the public key does not exist when deleting the private key" do
      allow(Puppet::FileSystem).to receive(:unlink).with(Puppet::FileSystem.pathname(@private_key_path))

      allow(Puppet::FileSystem).to receive(:exist?).with(Puppet::FileSystem.pathname(@private_key_path)).and_return(true)
      expect(Puppet::FileSystem).to receive(:exist?).with(Puppet::FileSystem.pathname(@public_key_path)).and_return(false)
      expect(Puppet::FileSystem).not_to receive(:unlink).with(Puppet::FileSystem.pathname(@public_key_path))

      @searcher.destroy(@request)
    end
  end
end
