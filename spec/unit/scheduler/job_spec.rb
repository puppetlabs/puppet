#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/scheduler'

describe Puppet::Scheduler::Job do
  let(:run_interval) { 10 }
  let(:job) { described_class.new(run_interval) }

  it "has a minimum run interval of 0" do
    Puppet::Scheduler::Job.new(-1).run_interval.should == 0
  end

  describe "when not run yet" do
    it "is ready" do
      job.ready?(2).should be
    end

    it "gives the time to next run as 0" do
      job.interval_to_next_from(2).should == 0
    end
  end

  describe "when run at least once" do
    let(:last_run) { 50 }

    before(:each) do
      job.run(last_run)
    end

    it "is ready when the time is greater than the last run plus the interval" do
      job.ready?(last_run + run_interval + 1).should be
    end

    it "is ready when the time is equal to the last run plus the interval" do
      job.ready?(last_run + run_interval).should be
    end

    it "is not ready when the time is less than the last run plus the interval" do
      job.ready?(last_run + run_interval - 1).should_not be
    end

    context "when calculating the next run" do
      it "returns the run interval if now == last run" do
        job.interval_to_next_from(last_run).should == run_interval
      end

      it "when time is between the last and next runs gives the remaining portion of the run_interval" do
        time_since_last_run = 2
        now = last_run + time_since_last_run
        job.interval_to_next_from(now).should == run_interval - time_since_last_run
      end

      it "when time is later than last+interval returns 0" do
        time_since_last_run = run_interval + 5
        now = last_run + time_since_last_run
        job.interval_to_next_from(now).should == 0
      end
    end
  end

  it "starts enabled" do
    job.enabled?.should be
  end

  it "can be disabled" do
    job.disable
    job.enabled?.should_not be
  end

  it "has the job instance as a parameter" do
    passed_job = nil
    job = Puppet::Scheduler::Job.new(run_interval) do |j|
      passed_job = j
    end
    job.run(5)

    passed_job.should eql(job)
  end
end
