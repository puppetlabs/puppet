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
      :provider   => provider
    )
  end

  let(:provider) { described_class.new(:name => 'myuser') }

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
      resource[:expiry] = "1997-06-01"
      provider.addcmd.must == ['/usr/sbin/useradd', '-e', 'June 01 1997', 'myuser']
    end
  end
end
