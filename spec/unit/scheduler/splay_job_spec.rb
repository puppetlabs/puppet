#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/scheduler'

describe Puppet::Scheduler::SplayJob do
  let(:run_interval) { 10 }
  let(:last_run) { 50 }
  let(:splay_limit) { 5 }
  let(:start_time) { 23 }
  let(:job) { described_class.new(run_interval, splay_limit) }

  it "does not apply a splay after the first run" do
    job.run(last_run)
    job.interval_to_next_from(last_run).should == run_interval
  end

  it "calculates the first run splayed from the start time" do
    job.start_time = start_time

    job.interval_to_next_from(start_time).should == job.splay
  end

  it "interval to the next run decreases as time advances" do
    time_passed = 3
    job.start_time = start_time

    job.interval_to_next_from(start_time + time_passed).should == job.splay - time_passed
  end

  it "is not immediately ready if splayed" do
    job.start_time = start_time
    job.expects(:splay).returns(6)
    job.ready?(start_time).should_not be
  end
end
