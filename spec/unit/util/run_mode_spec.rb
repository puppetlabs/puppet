#! /usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Util::RunMode do
  before do
    @run_mode = Puppet::Util::RunMode.new('fake')
  end

  it "should have confdir /etc/puppet when run as root" do
    Puppet.features.stubs(:root?).returns(true)
    etcdir = Puppet.features.microsoft_windows? ? File.join(Dir::COMMON_APPDATA, "PuppetLabs", "puppet", "etc") : '/etc/puppet'
    # REMIND: issue with windows backslashes
    @run_mode.conf_dir.should == File.expand_path(etcdir)
  end

  it "should have confdir ~/.puppet when run as non-root" do
    Puppet.features.stubs(:root?).returns(false)
    @run_mode.conf_dir.should == File.expand_path("~/.puppet")
  end

  it "should have vardir /var/lib/puppet when run as root" do
    Puppet.features.stubs(:root?).returns(true)
    vardir = Puppet.features.microsoft_windows? ? File.join(Dir::COMMON_APPDATA, "PuppetLabs", "puppet", "var") : '/var/lib/puppet'
    # REMIND: issue with windows backslashes
    @run_mode.var_dir.should == File.expand_path(vardir)
  end

  it "should have vardir ~/.puppet/var when run as non-root" do
    Puppet.features.stubs(:root?).returns(false)
    @run_mode.var_dir.should == File.expand_path("~/.puppet/var")
  end

  it "should have rundir depend on vardir" do
    @run_mode.run_dir.should == '$vardir/run'
  end


  it "should have logopts return a hash with $vardir/log and other metadata if runmode is master" do
    pending("runmode.logopts functionality is being moved")
    @run_mode.expects(:master?).returns true
    @run_mode.logopts.should == {
      :default => "$vardir/log",
      :mode    => 0750,
      :owner   => "service",
      :group   => "service",
      :desc    => "The Puppet log directory.",
    }
  end
end
