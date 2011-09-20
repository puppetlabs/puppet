#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Type.type(:file).provider(:posix), :if => Puppet.features.posix? do
  include PuppetSpec::Files

  let(:path) { tmpfile('posix_file_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :mode => 0777, :provider => described_class.name }
  let(:provider) { resource.provider }

  describe "#mode" do
    it "should return a string with the higher-order bits stripped away" do
      FileUtils.touch(path)
      File.chmod(0644, path)

      provider.mode.should == '644'
    end

    it "should return absent if the file doesn't exist" do
      provider.mode.should == :absent
    end
  end

  describe "#mode=" do
    it "should chmod the file to the specified value" do
      FileUtils.touch(path)
      File.chmod(0644, path)

      provider.mode = '0755'

      provider.mode.should == '755'
    end

    it "should pass along any errors encountered" do
      expect do
        provider.mode = '644'
      end.to raise_error(Puppet::Error, /failed to set mode/)
    end
  end

  describe "#uid2name" do
    it "should return the name of the user identified by the id" do
      Etc.stubs(:getpwuid).with(501).returns(Struct::Passwd.new('jilluser', nil, 501))

      provider.uid2name(501).should == 'jilluser'
    end

    it "should return the argument if it's already a name" do
      provider.uid2name('jilluser').should == 'jilluser'
    end

    it "should return nil if the argument is above the maximum uid" do
      provider.uid2name(Puppet[:maximum_uid] + 1).should == nil
    end

    it "should return nil if the user doesn't exist" do
      Etc.expects(:getpwuid).raises(ArgumentError, "can't find user for 999")

      provider.uid2name(999).should == nil
    end
  end

  describe "#name2uid" do
    it "should return the id of the user if it exists" do
      passwd = Struct::Passwd.new('bobbo', nil, 502)

      Etc.stubs(:getpwnam).with('bobbo').returns(passwd)
      Etc.stubs(:getpwuid).with(502).returns(passwd)

      provider.name2uid('bobbo').should == 502
    end

    it "should return the argument if it's already an id" do
      provider.name2uid('503').should == 503
    end

    it "should return false if the user doesn't exist" do
      Etc.stubs(:getpwnam).with('chuck').raises(ArgumentError, "can't find user for chuck")

      provider.name2uid('chuck').should == false
    end
  end

  describe "#owner" do
    it "should return the uid of the file owner" do
      FileUtils.touch(path)
      owner = File.stat(path).uid

      provider.owner.should == owner
    end

    it "should return absent if the file can't be statted" do
      provider.owner.should == :absent
    end

    it "should warn and return :silly if the value is beyond the maximum uid" do
      stat = stub('stat', :uid => Puppet[:maximum_uid] + 1)
      resource.stubs(:stat).returns(stat)

      provider.owner.should == :silly
      @logs.should be_any {|log| log.level == :warning and log.message =~ /Apparently using negative UID/}
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
end
