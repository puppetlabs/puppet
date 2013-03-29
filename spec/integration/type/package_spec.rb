#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package), "when choosing a default package provider" do
  before do
    # the default provider is cached.
    Puppet::Type.type(:package).defaultprovider = nil
  end

  def provider_name(os)
    if Facter.value(:operatingsystem) == 'Solaris' && Puppet::Util::Package.versioncmp(Facter.value(:kernelrelease), '5.11') >= 0
      :pkg
    else
      {"Ubuntu" => :apt, "Debian" => :apt, "Darwin" => :pkgdmg, "RedHat" => :up2date, "Fedora" => :yum, "FreeBSD" => :ports, "OpenBSD" => :openbsd, "Solaris" => :sun, "DragonFly" => :pkgin, "OpenWrt" => :opkg}[os]
    end
  end

  it "should have a default provider" do
    Puppet::Type.type(:package).defaultprovider.should_not be_nil
  end

  it "should choose the correct provider each platform" do
    unless default_provider = provider_name(Facter.value(:operatingsystem))
      pending("No default provider specified in this test for #{Facter.value(:operatingsystem)}")
    end
    Puppet::Type.type(:package).defaultprovider.name.should == default_provider
  end
end
