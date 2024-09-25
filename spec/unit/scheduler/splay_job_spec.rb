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
    expect(job.interval_to_next_from(last_run)).to eq(run_interval)
  end

  it "calculates the first run splayed from the start time" do
    job.start_time = start_time

    expect(job.interval_to_next_from(start_time)).to eq(job.splay)
  end

  it "interval to the next run decreases as time advances" do
    time_passed = 3
    job.start_time = start_time

    expect(job.interval_to_next_from(start_time + time_passed)).to eq(job.splay - time_passed)
  end

  it "is not immediately ready if splayed" do
    job.start_time = start_time
    expect(job).to receive(:splay).and_return(6)
    expect(job.ready?(start_time)).not_to be
  end

  it "does not apply a splay if the splaylimit is unchanged" do
    old_splay = job.splay
    job.splay_limit = splay_limit
    expect(job.splay).to eq(old_splay)
  end

  it "applies a splay if the splaylimit is changed" do
    new_splay = 999
    allow(job).to receive(:rand).and_return(new_splay)
    job.splay_limit = splay_limit + 1
    expect(job.splay).to eq(new_splay)
  end
end
