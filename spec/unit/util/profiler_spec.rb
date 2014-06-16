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
    subject.profile("hi") {}
    profiler.context = "hi"
    profiler.description = "hi"
  end

  class TestProfiler
    attr_accessor :context, :description

    def start(description)
      description
    end

    def finish(context, description)
      @context = context
      @description = description
    end
  end
end

