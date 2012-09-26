#! /usr/bin/env ruby
require 'spec_helper'

provider = Puppet::Type.type(:service).provider(:init)

describe provider do
  describe "when running on FreeBSD" do
    before :each do
      Facter.stubs(:value).with(:operatingsystem).returns 'FreeBSD'
    end

    it "should set its default path to include /etc/rc.d and /usr/local/etc/rc.d" do
      provider.defpath.should == ["/etc/rc.d", "/usr/local/etc/rc.d"]
    end
  end

  describe "when running on HP-UX" do
    before :each do
      Facter.stubs(:value).with(:operatingsystem).returns 'HP-UX'
    end

    it "should set its default path to include /sbin/init.d" do
      provider.defpath.should == "/sbin/init.d"
    end
  end

  describe "when running on Archlinux" do
    before :each do
      Facter.stubs(:value).with(:operatingsystem).returns 'Archlinux'
    end

    it "should set its default path to include /etc/rc.d" do
      provider.defpath.should == "/etc/rc.d"
    end
  end

  describe "when not running on FreeBSD, HP-UX or Archlinux" do
    before :each do
      Facter.stubs(:value).with(:operatingsystem).returns 'RedHat'
    end

    it "should set its default path to include /etc/init.d" do
      provider.defpath.should == "/etc/init.d"
    end
  end
end
