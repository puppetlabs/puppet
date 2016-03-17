#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:file).provider(:posix), :if => Puppet.features.posix? do
  include PuppetSpec::Files

  let(:path) { tmpfile('posix_file_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :mode => '0777', :provider => described_class.name }
  let(:provider) { resource.provider }

  describe "#mode" do
    it "should return a string with the higher-order bits stripped away" do
      FileUtils.touch(path)
      File.chmod(0644, path)

      expect(provider.mode).to eq('0644')
    end

    it "should return absent if the file doesn't exist" do
      expect(provider.mode).to eq(:absent)
    end
  end

  describe "#mode=" do
    it "should chmod the file to the specified value" do
      FileUtils.touch(path)
      File.chmod(0644, path)

      provider.mode = '0755'

      expect(provider.mode).to eq('0755')
    end

    it "should pass along any errors encountered" do
      expect do
        provider.mode = '0644'
      end.to raise_error(Puppet::Error, /failed to set mode/)
    end
  end

  describe "#uid2name" do
    it "should return the name of the user identified by the id" do
      Etc.stubs(:getpwuid).with(501).returns(Struct::Passwd.new('jilluser', nil, 501))

      expect(provider.uid2name(501)).to eq('jilluser')
    end

    it "should return the argument if it's already a name" do
      expect(provider.uid2name('jilluser')).to eq('jilluser')
    end

    it "should return nil if the argument is above the maximum uid" do
      expect(provider.uid2name(Puppet[:maximum_uid] + 1)).to eq(nil)
    end

    it "should return nil if the user doesn't exist" do
      Etc.expects(:getpwuid).raises(ArgumentError, "can't find user for 999")

      expect(provider.uid2name(999)).to eq(nil)
    end
  end

  describe "#name2uid" do
    it "should return the id of the user if it exists" do
      passwd = Struct::Passwd.new('bobbo', nil, 502)

      Etc.stubs(:getpwnam).with('bobbo').returns(passwd)
      Etc.stubs(:getpwuid).with(502).returns(passwd)

      expect(provider.name2uid('bobbo')).to eq(502)
    end

    it "should return the argument if it's already an id" do
      expect(provider.name2uid('503')).to eq(503)
    end

    it "should return false if the user doesn't exist" do
      Etc.stubs(:getpwnam).with('chuck').raises(ArgumentError, "can't find user for chuck")

      expect(provider.name2uid('chuck')).to eq(false)
    end
  end

  describe "#owner" do
    it "should return the uid of the file owner" do
      FileUtils.touch(path)
      owner = Puppet::FileSystem.stat(path).uid

      expect(provider.owner).to eq(owner)
    end

    it "should return absent if the file can't be statted" do
      expect(provider.owner).to eq(:absent)
    end

    it "should warn and return :silly if the value is beyond the maximum uid" do
      stat = stub('stat', :uid => Puppet[:maximum_uid] + 1)
      resource.stubs(:stat).returns(stat)

      expect(provider.owner).to eq(:silly)
      expect(@logs).to be_any {|log| log.level == :warning and log.message =~ /Apparently using negative UID/}
    end
  end

  describe "#owner=" do
    it "should set the owner but not the group of the file" do
      File.expects(:lchown).with(15, nil, resource[:path])

      provider.owner = 15
    end

    it "should chown a link if managing links" do
      resource[:links] = :manage
      File.expects(:lchown).with(20, nil, resource[:path])

      provider.owner = 20
    end

    it "should chown a link target if following links" do
      resource[:links] = :follow
      File.expects(:chown).with(20, nil, resource[:path])

      provider.owner = 20
    end

    it "should pass along any error encountered setting the owner" do
      File.expects(:lchown).raises(ArgumentError)

      expect { provider.owner = 25 }.to raise_error(Puppet::Error, /Failed to set owner to '25'/)
    end
  end

  describe "#gid2name" do
    it "should return the name of the group identified by the id" do
      Etc.stubs(:getgrgid).with(501).returns(Struct::Passwd.new('unicorns', nil, nil, 501))

      expect(provider.gid2name(501)).to eq('unicorns')
    end

    it "should return the argument if it's already a name" do
      expect(provider.gid2name('leprechauns')).to eq('leprechauns')
    end

    it "should return nil if the argument is above the maximum gid" do
      expect(provider.gid2name(Puppet[:maximum_uid] + 1)).to eq(nil)
    end

    it "should return nil if the group doesn't exist" do
      Etc.expects(:getgrgid).raises(ArgumentError, "can't find group for 999")

      expect(provider.gid2name(999)).to eq(nil)
    end
  end

  describe "#name2gid" do
    it "should return the id of the group if it exists" do
      passwd = Struct::Passwd.new('penguins', nil, nil, 502)

      Etc.stubs(:getgrnam).with('penguins').returns(passwd)
      Etc.stubs(:getgrgid).with(502).returns(passwd)

      expect(provider.name2gid('penguins')).to eq(502)
    end

    it "should return the argument if it's already an id" do
      expect(provider.name2gid('503')).to eq(503)
    end

    it "should return false if the group doesn't exist" do
      Etc.stubs(:getgrnam).with('wombats').raises(ArgumentError, "can't find group for wombats")

      expect(provider.name2gid('wombats')).to eq(false)
    end

  end

  describe "#group" do
    it "should return the gid of the file group" do
      FileUtils.touch(path)
      group = Puppet::FileSystem.stat(path).gid

      expect(provider.group).to eq(group)
    end

    it "should return absent if the file can't be statted" do
      expect(provider.group).to eq(:absent)
    end

    it "should warn and return :silly if the value is beyond the maximum gid" do
      stat = stub('stat', :gid => Puppet[:maximum_uid] + 1)
      resource.stubs(:stat).returns(stat)

      expect(provider.group).to eq(:silly)
      expect(@logs).to be_any {|log| log.level == :warning and log.message =~ /Apparently using negative GID/}
    end
  end

  describe "#group=" do
    it "should set the group but not the owner of the file" do
      File.expects(:lchown).with(nil, 15, resource[:path])

      provider.group = 15
    end

    it "should change the group for a link if managing links" do
      resource[:links] = :manage
      File.expects(:lchown).with(nil, 20, resource[:path])

      provider.group = 20
    end

    it "should change the group for a link target if following links" do
      resource[:links] = :follow
      File.expects(:chown).with(nil, 20, resource[:path])

      provider.group = 20
    end

    it "should pass along any error encountered setting the group" do
      File.expects(:lchown).raises(ArgumentError)

      expect { provider.group = 25 }.to raise_error(Puppet::Error, /Failed to set group to '25'/)
    end
  end

  describe "when validating" do
    it "should not perform any validation" do
      resource.validate
    end
  end
end
