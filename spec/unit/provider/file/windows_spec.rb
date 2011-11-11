#!/usr/bin/env rspec

require 'spec_helper'
if Puppet.features.microsoft_windows?
  require 'puppet/util/windows'
  class WindowsSecurity
    extend Puppet::Util::Windows::Security
  end
end

describe Puppet::Type.type(:file).provider(:windows), :if => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  let(:path) { tmpfile('windows_file_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :mode => 0777, :provider => described_class.name }
  let(:provider) { resource.provider }

  describe "#mode" do
    it "should return a string with the higher-order bits stripped away" do
      FileUtils.touch(path)
      WindowsSecurity.set_mode(0644, path)

      provider.mode.should == '644'
    end

    it "should return absent if the file doesn't exist" do
      provider.mode.should == :absent
    end
  end

  describe "#mode=" do
    it "should chmod the file to the specified value" do
      FileUtils.touch(path)
      WindowsSecurity.set_mode(0644, path)

      provider.mode = '0755'

      provider.mode.should == '755'
    end

    it "should pass along any errors encountered" do
      expect do
        provider.mode = '644'
      end.to raise_error(Puppet::Error, /failed to set mode/)
    end
  end

  describe "#id2name" do
    it "should return the name of the user identified by the sid" do
      result = [stub('user', :name => 'quinn')]
      Puppet::Util::ADSI.stubs(:execquery).returns(result)

      provider.id2name('S-1-1-50').should == 'quinn'
    end

    it "should return the argument if it's already a name" do
      provider.id2name('flannigan').should == 'flannigan'
    end

    it "should return nil if the user doesn't exist" do
      Puppet::Util::ADSI.stubs(:execquery).returns []

      provider.id2name('S-1-1-50').should == nil
    end
  end

  describe "#name2id" do
    it "should return the sid of the user" do
      Puppet::Util::ADSI.stubs(:execquery).returns [stub('account', :Sid => 'S-1-1-50')]

      provider.name2id('anybody').should == 'S-1-1-50'
    end

    it "should return the argument if it's already a sid" do
      provider.name2id('S-1-1-50').should == 'S-1-1-50'
    end

    it "should return nil if the user doesn't exist" do
      Puppet::Util::ADSI.stubs(:execquery).returns []

      provider.name2id('someone').should == nil
    end
  end

  describe "#owner" do
    it "should return the sid of the owner if the file does exist" do
      FileUtils.touch(resource[:path])
      provider.stubs(:get_owner).with(resource[:path]).returns('S-1-1-50')

      provider.owner.should == 'S-1-1-50'
    end

    it "should return absent if the file doesn't exist" do
      provider.owner.should == :absent
    end
  end

  describe "#owner=" do
    it "should set the owner to the specified value" do
      provider.expects(:set_owner).with('S-1-1-50', resource[:path])
      provider.owner = 'S-1-1-50'
    end

    it "should propagate any errors encountered when setting the owner" do
      provider.stubs(:set_owner).raises(ArgumentError)

      expect { provider.owner = 'S-1-1-50' }.to raise_error(Puppet::Error, /Failed to set owner/)
    end
  end

  describe "#group" do
    it "should return the sid of the group if the file does exist" do
      FileUtils.touch(resource[:path])
      provider.stubs(:get_group).with(resource[:path]).returns('S-1-1-50')

      provider.group.should == 'S-1-1-50'
    end

    it "should return absent if the file doesn't exist" do
      provider.group.should == :absent
    end
  end

  describe "#group=" do
    it "should set the group to the specified value" do
      provider.expects(:set_group).with('S-1-1-50', resource[:path])
      provider.group = 'S-1-1-50'
    end

    it "should propagate any errors encountered when setting the group" do
      provider.stubs(:set_group).raises(ArgumentError)

      expect { provider.group = 'S-1-1-50' }.to raise_error(Puppet::Error, /Failed to set group/)
    end
  end

  describe "when validating" do
    {:owner => 'foo', :group => 'foo', :mode => 0777}.each do |k,v|
      it "should fail if the filesystem doesn't support ACLs and we're managing #{k}" do
        described_class.any_instance.stubs(:supports_acl?).returns false

        expect {
          Puppet::Type.type(:file).new :path => path, k => v
        }.to raise_error(Puppet::Error, /Can only manage owner, group, and mode on filesystems that support Windows ACLs, such as NTFS/)
      end
    end

    it "should not fail if the filesystem doesn't support ACLs and we're not managing permissions" do
      described_class.any_instance.stubs(:supports_acl?).returns false

      Puppet::Type.type(:file).new :path => path
    end
  end
end
