#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/scheduler'

describe Puppet::Scheduler::Scheduler do
  let(:now) { 183550 }
  let(:timer) { MockTimer.new(now) }

  class MockTimer
    attr_reader :wait_for_calls

    def initialize(start=1729)
      @now = start
      @wait_for_calls = []
    end

    def wait_for(seconds)
      @wait_for_calls << seconds
      @now += seconds
    end

    def now
      @now
    end
  end

  def one_time_job(interval)
    Puppet::Scheduler::Job.new(interval) { |j| j.disable }
  end

  def disabled_job(interval)
    job = Puppet::Scheduler::Job.new(interval) { |j| j.disable }
    job.disable
    job
  end

  it "uses the minimum interval" do
    later_job = one_time_job(7)
    earlier_job = one_time_job(2)
    scheduler = Puppet::Scheduler::Scheduler.new([later_job, earlier_job], timer)
    later_job.last_run = now
    earlier_job.last_run = now

    scheduler.run_loop

    timer.wait_for_calls.should == [2, 5]
  end

  it "doesn't run disabled jobs" do
    disabled = disabled_job(4)
    scheduler = Puppet::Scheduler::Scheduler.new([disabled], timer)
    disabled.expects(:run).never

    scheduler.run_ready
  end

  it "ignores disabled jobs when calculating intervals" do
    enabled = one_time_job(7)
    enabled.last_run = now
    disabled = disabled_job(2)
    scheduler = Puppet::Scheduler::Scheduler.new([enabled, disabled], timer)

    scheduler.run_loop

    timer.wait_for_calls.should == [7]
  end

  it "asks the timer to wait for the job interval" do
    job = one_time_job(5)
    job.last_run = now
    scheduler = Puppet::Scheduler::Scheduler.new([job], timer)

    scheduler.run_loop

    timer.wait_for_calls.should == [5]
  end

  it "does not run when there are no jobs" do
    timer = mock 'no run timer'
    scheduler = Puppet::Scheduler::Scheduler.new([], timer)

    timer.stubs(:now).returns(now)
    timer.expects(:wait_for).never

    scheduler.run_loop
  end

  it "does not run when there are only disabled jobs" do
    timer = mock 'no run timer'
    disabled_job = Puppet::Scheduler::Job.new(0)
    scheduler = Puppet::Scheduler::Scheduler.new([disabled_job], timer)

    disabled_job.disable
    timer.stubs(:now).returns(now)
    timer.expects(:wait_for).never

    scheduler.run_loop
  end

  it "stops running when there are no more enabled jobs" do
    timer = mock 'run once timer'
    disabling_job = Puppet::Scheduler::Job.new(0) do |j|
      j.disable
    end
    scheduler = Puppet::Scheduler::Scheduler.new([disabling_job], timer)

    timer.stubs(:now).returns(now)
    timer.expects(:wait_for).once

    scheduler.run_loop
  end

  it "marks the start of the run loop" do
    disabled_job = Puppet::Scheduler::Job.new(0)

    disabled_job.disable

    scheduler = Puppet::Scheduler::Scheduler.new([disabled_job], timer)
    scheduler.run_loop

    disabled_job.start_time.should == now
  end
end
