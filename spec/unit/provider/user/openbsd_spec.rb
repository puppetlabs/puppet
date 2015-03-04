#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:user).provider(:openbsd) do

  before :each do
    described_class.stubs(:command).with(:password).returns '/usr/sbin/passwd'
    described_class.stubs(:command).with(:add).returns '/usr/sbin/useradd'
    described_class.stubs(:command).with(:modify).returns '/usr/sbin/usermod'
    described_class.stubs(:command).with(:delete).returns '/usr/sbin/userdel'
  end

  let(:resource) do
    Puppet::Type.type(:user).new(
      :name       => 'myuser',
      :managehome => :false,
      :system     => :false,
      :loginclass => 'staff',
      :provider   => provider
    )
  end

  let(:provider) { described_class.new(:name => 'myuser') }

  let(:shadow_entry) {
    return unless Puppet.features.libshadow?
    entry = Struct::PasswdEntry.new
    entry[:sp_namp]   = 'myuser' # login name
    entry[:sp_loginclass] = 'staff' # login class
    entry
  }

  describe "#expiry=" do
    it "should pass expiry to usermod as MM/DD/YY" do
      resource[:expiry] = '2014-11-05'
      provider.expects(:execute).with(['/usr/sbin/usermod', '-e', 'November 05 2014', 'myuser'])
      provider.expiry = '2014-11-05'
    end

    it "should use -e with an empty string when the expiry property is removed" do
      resource[:expiry] = :absent
      provider.expects(:execute).with(['/usr/sbin/usermod', '-e', '', 'myuser'])
      provider.expiry = :absent
    end
  end

  describe "#addcmd" do
    it "should return an array with the full command and expiry as MM/DD/YY" do
      Facter.stubs(:value).with(:osfamily).returns('OpenBSD')
      resource[:expiry] = "1997-06-01"
      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', 'June 01 1997', 'myuser'])
    end
  end

  describe "#loginclass" do
    before :each do
      resource
    end

    it "should return the loginclass if set", :if => Puppet.features.libshadow? do
      Shadow::Passwd.expects(:getspnam).with('myuser').returns shadow_entry
      provider.send(:loginclass).should == 'staff'
    end

    it "should return the empty string when loginclass isn't set", :if => Puppet.features.libshadow? do
      shadow_entry[:sp_loginclass] = ''
      Shadow::Passwd.expects(:getspnam).with('myuser').returns shadow_entry
      provider.send(:loginclass).should == ''
    end

    it "should return nil when loginclass isn't available", :if => Puppet.features.libshadow? do
      shadow_entry[:sp_loginclass] = nil
      Shadow::Passwd.expects(:getspnam).with('myuser').returns shadow_entry
      provider.send(:loginclass).should be_nil
    end
  end
end
