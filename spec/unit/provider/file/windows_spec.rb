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

  describe "#uid2name" do
    it "should return the name of the user identified by the sid" do
      result = [stub('user', :name => 'quinn')]
      Puppet::Util::ADSI.stubs(:execquery).returns(result)

      provider.uid2name('S-1-1-50').should == 'quinn'
    end

    it "should return the argument if it's already a name" do
      provider.uid2name('flannigan').should == 'flannigan'
    end

    it "should return nil if the user doesn't exist" do
      Puppet::Util::ADSI.stubs(:execquery).returns []

      provider.uid2name('S-1-1-50').should == nil
    end
  end

  describe "#name2uid" do
    it "should return the sid of the user" do
      Puppet::Util::ADSI.stubs(:execquery).returns [stub('account', :Sid => 'S-1-1-50')]

      provider.name2uid('anybody').should == 'S-1-1-50'
    end

    it "should return the argument if it's already a sid" do
      provider.name2uid('S-1-1-50').should == 'S-1-1-50'
    end

    it "should return nil if the user doesn't exist" do
      Puppet::Util::ADSI.stubs(:execquery).returns []

      provider.name2uid('someone').should == nil
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
end
