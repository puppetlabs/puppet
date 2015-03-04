require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler do
  let(:profiler) { TestProfiler.new() }

  it "supports adding profilers" do
    subject.add_profiler(profiler)
    expect(subject.current[0]).to eq(profiler)
  end

  it "supports removing profilers" do
    subject.add_profiler(profiler)
    subject.remove_profiler(profiler)
    expect(subject.current.length).to eq(0)
  end

  it "supports clearing profiler list" do
    subject.add_profiler(profiler)
    subject.clear
    expect(subject.current.length).to eq(0)
  end

  it "supports profiling" do
    subject.add_profiler(profiler)
    subject.profile("hi", ["mymetric"]) {}
    expect(profiler.context[:metric_id]).to eq(["mymetric"])
    expect(profiler.context[:description]).to eq("hi")
    expect(profiler.description).to eq("hi")
  end

  class TestProfiler
    attr_accessor :context, :metric, :description

    def start(description, metric_id)
      {:metric_id => metric_id,
       :description => description}
    end

    def finish(context, description, metric_id)
      @context = context
      @metric_id = metric_id
      @description = description
    end
  end
end

