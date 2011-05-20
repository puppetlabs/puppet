#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Util::RunMode do
  before do
    @run_mode = Puppet::Util::RunMode.new('fake')
  end

  it "should have confdir /etc/puppet when run as root" do
    Puppet.features.stubs(:root?).returns(true)
    @run_mode.conf_dir.should == '/etc/puppet'
  end

  it "should have confdir ~/.puppet when run as non-root" do
    Puppet.features.stubs(:root?).returns(false)
    @run_mode.expects(:expand_path).with("~/.puppet").returns("~/.puppet")
    @run_mode.conf_dir.should == "~/.puppet"
  end

  it "should have vardir /var/lib/puppet when run as root" do
    Puppet.features.stubs(:root?).returns(true)
    @run_mode.var_dir.should == '/var/lib/puppet'
  end

  it "should have vardir ~/.puppet/var when run as non-root" do
    Puppet.features.stubs(:root?).returns(false)
    @run_mode.expects(:expand_path).with("~/.puppet/var").returns("~/.puppet/var")
    @run_mode.var_dir.should == "~/.puppet/var"
  end

  it "should have rundir depend on vardir" do
    @run_mode.run_dir.should == '$vardir/run'
  end

  it "should have logopts return an array with $vardir/log if runmode is not master" do
    @run_mode.expects(:master?).returns false
    @run_mode.logopts.should == ["$vardir/log", "The Puppet log directory."]
  end

  it "should have logopts return a hash with $vardir/log and other metadata if runmode is master" do
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
