require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler do
  let(:profiler) { TestProfiler.new() }

  it "supports adding profilers" do
    subject.add_profiler(profiler)
    subject.current[0].should == profiler
  end

  it "supports removing profilers" do
    subject.add_profiler(profiler)
    subject.remove_profiler(profiler)
    subject.current.length.should == 0
  end

  it "supports clearing profiler list" do
    subject.add_profiler(profiler)
    subject.clear
    subject.current.length.should == 0
  end

  it "supports profiling" do
    subject.add_profiler(profiler)
    subject.profile("hi", ["mymetric"]) {}
    profiler.context[:metric_id].should == ["mymetric"]
    profiler.context[:description].should == "hi"
    profiler.description.should == "hi"
  end

  it "supports profiling without a metric id" do
    subject.add_profiler(profiler)
    subject.profile("hi") {}
    profiler.context[:metric_id].should == nil
    profiler.context[:description].should == "hi"
    profiler.description.should == "hi"
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

