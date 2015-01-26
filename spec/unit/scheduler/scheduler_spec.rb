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

  let(:scheduler) { Puppet::Scheduler::Scheduler.new(timer) }

  it "uses the minimum interval" do
    later_job = one_time_job(7)
    earlier_job = one_time_job(2)
    later_job.last_run = now
    earlier_job.last_run = now

    scheduler.run_loop([later_job, earlier_job])

    expect(timer.wait_for_calls).to eq([2, 5])
  end

  it "ignores disabled jobs when calculating intervals" do
    enabled = one_time_job(7)
    enabled.last_run = now
    disabled = disabled_job(2)

    scheduler.run_loop([enabled, disabled])

    expect(timer.wait_for_calls).to eq([7])
  end

  it "asks the timer to wait for the job interval" do
    job = one_time_job(5)
    job.last_run = now

    scheduler.run_loop([job])

    expect(timer.wait_for_calls).to eq([5])
  end

  it "does not run when there are no jobs" do
    scheduler.run_loop([])

    expect(timer.wait_for_calls).to be_empty
  end

  it "does not run when there are only disabled jobs" do
    disabled_job = Puppet::Scheduler::Job.new(0)
    disabled_job.disable

    scheduler.run_loop([disabled_job])

    expect(timer.wait_for_calls).to be_empty
  end

  it "stops running when there are no more enabled jobs" do
    disabling_job = Puppet::Scheduler::Job.new(0) do |j|
      j.disable
    end

    scheduler.run_loop([disabling_job])

    expect(timer.wait_for_calls.size).to eq(1)
  end

  it "marks the start of the run loop" do
    disabled_job = Puppet::Scheduler::Job.new(0)

    disabled_job.disable

    scheduler.run_loop([disabled_job])

    expect(disabled_job.start_time).to eq(now)
  end

  it "calculates the next interval from the start of a job" do
    countdown = 2
    slow_job = Puppet::Scheduler::Job.new(10) do |job|
      timer.wait_for(3)
      countdown -= 1
      job.disable if countdown == 0
    end

    scheduler.run_loop([slow_job])

    expect(timer.wait_for_calls).to eq([0, 3, 7, 3])
  end
end
