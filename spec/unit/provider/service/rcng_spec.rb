#!/usr/bin/env ruby

require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:rcng)

describe provider_class, :unless => Puppet.features.microsoft_windows? do
  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
    Facter.stubs(:value).with(:operatingsystem).returns :netbsd
    Facter.stubs(:value).with(:osfamily).returns 'NetBSD'
    described_class.stubs(:defpath).returns('/etc/rc.d')
    @provider = provider_class.new
    @provider.stubs(:initscript)
  end

  describe "#enable" do
    it "should have an enable method" do
      expect(@provider).to respond_to(:enable)
    end

    it "should set the proper contents to enable" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Dir.stubs(:mkdir).with('/etc/rc.conf.d')
      fh = stub 'fh'
      Puppet::Util.expects(:replace_file).with('/etc/rc.conf.d/sshd', 0644).yields(fh)
      fh.expects(:puts).with("sshd=${sshd:=YES}\n")
      provider.enable
    end

    it "should set the proper contents to enable when disabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Dir.stubs(:mkdir).with('/etc/rc.conf.d')
      File.stubs(:read).with('/etc/rc.conf.d/sshd').returns("sshd_enable=\"NO\"\n")
      fh = stub 'fh'
      Puppet::Util.expects(:replace_file).with('/etc/rc.conf.d/sshd', 0644).yields(fh)
      fh.expects(:puts).with("sshd=${sshd:=YES}\n")
      provider.enable
    end
  end
end
