#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/scheduler'

describe Puppet::Scheduler::Scheduler do
  let(:now) { 183550 }
  let(:timer) { stub(:now => now, :wait_for => nil) }

  it "uses the minimum interval" do
    job1 = mock(:interval_to_next_from => 7, :enabled? => true)
    job2 = mock(:interval_to_next_from => 2, :enabled? => true)
    scheduler = Puppet::Scheduler::Scheduler.new([job1, job2], timer)
    scheduler.interval_to_next_run.should == 2
  end

  it "doesn't run disabled jobs" do
    job1 = stub(:enabled? => false, :ready? => true)
    job1.stubs(:run).raises(Exception, "Ran a disabled job")
    scheduler = Puppet::Scheduler::Scheduler.new([job1], timer)
    scheduler.run_ready
  end

  it "ignores disabled jobs when calculating intervals" do
    job1 = stub(:interval_to_next_from => 7, :enabled? => true)
    job2 = stub(:interval_to_next_from => 2, :enabled? => false)
    scheduler = Puppet::Scheduler::Scheduler.new([job1, job2], timer)
    scheduler.interval_to_next_run.should == 7
  end

  it "asks the timer to wait for the job interval" do
    timer.expects(:wait_for).with(5)
    job = stub(:interval_to_next_from => 5, :ready? => true, :enabled? => true, :run => nil)
    scheduler = Puppet::Scheduler::Scheduler.new([job], timer)
    scheduler.run_once
  end
end
