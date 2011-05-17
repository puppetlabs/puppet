#!/usr/bin/env rspec
require 'spec_helper'

provider = Puppet::Type.type(:service).provider(:init)

describe provider, :'fails_on_ruby_1.9.2' => true do
  describe "when running on FreeBSD", :if => (Facter.value(:operatingsystem) == "FreeBSD") do
    it "should set its default path to include /etc/init.d and /usr/local/etc/init.d" do
      provider.defpath.should == ["/etc/rc.d", "/usr/local/etc/rc.d"]
    end
  end

  describe "when running on HP-UX", :if => (Facter.value(:operatingsystem) == "HP-UX") do
    it "should set its default path to include /sbin/init.d" do
      provider.defpath.should == "/sbin/init.d"
    end
  end

  describe "when not running on FreeBSD or HP-UX", :if => (! %w{HP-UX FreeBSD}.include?(Facter.value(:operatingsystem))) do
    it "should set its default path to include /etc/init.d" do
      provider.defpath.should == "/etc/init.d"
    end
  end
end
