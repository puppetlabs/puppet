require 'spec_helper'
require 'puppet/util/profiler/manager'

describe Puppet::Util::Profiler::Manager do
  let(:profiler) { TestProfiler.new() }

  before :each do
    subject.add_profiler(profiler)
  end

  after :each do
    subject.remove_profiler(profiler)
  end

  it "returns the value of the profiled segment" do
    retval = subject.profile("Testing") { "the return value" }

    retval.should == "the return value"
  end

  it "propogates any errors raised in the profiled segment" do
    expect do
      subject.profile("Testing") { raise "a problem" }
    end.to raise_error("a problem")
  end

  it "makes the description and the context available to the `start` and `finish` methods" do
    subject.profile("Testing") { }

    profiler.context.should == "Testing"
    profiler.description.should == "Testing"
  end

  it "calls finish even when an error is raised" do
    begin
      subject.profile("Testing") { raise "a problem" }
    rescue
      profiler.context.should == "Testing"
    end
  end

  it "supports multiple profilers" do
    profiler2 = TestProfiler.new
    subject.add_profiler(profiler2)
    subject.profile("Testing") {}

    profiler.context.should == "Testing"
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

