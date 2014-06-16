require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::AroundProfiler do
  let(:child) { TestProfiler.new() }
  let(:profiler) { Puppet::Util::Profiler::AroundProfiler.new }

  before :each do
    profiler.add_profiler(child)
  end

  it "returns the value of the profiled segment" do
    retval = profiler.profile("Testing") { "the return value" }

    retval.should == "the return value"
  end

  it "propogates any errors raised in the profiled segment" do
    expect do
      profiler.profile("Testing") { raise "a problem" }
    end.to raise_error("a problem")
  end

  it "makes the description and the context available to the `start` and `finish` methods" do
    profiler.profile("Testing") { }

    child.context.should == "Testing"
    child.description.should == "Testing"
  end

  it "calls finish even when an error is raised" do
    begin
      profiler.profile("Testing") { raise "a problem" }
    rescue
      child.context.should == "Testing"
    end
  end

  it "supports multiple profilers" do
    profiler2 = TestProfiler.new
    profiler.add_profiler(profiler2)
    profiler.profile("Testing") {}

    child.context.should == "Testing"
    profiler2.context.should == "Testing"
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

