#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Util::RunMode do
  before do
    @run_mode = Puppet::Util::RunMode.new('fake')
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
