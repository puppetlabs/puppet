require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::Logging do
  let(:logger) { SimpleLog.new }
  let(:identifier) { "Profiling ID" }
  let(:profiler) { TestLoggingProfiler.new(logger, identifier) }

  it "returns the value of the profiled segment" do
    retval = profiler.profile("Testing") { "the return value" }

    retval.should == "the return value"
  end

  it "propogates any errors raised in the profiled segment" do
    expect do
      profiler.profile("Testing") { raise "a problem" }
    end.to raise_error("a problem")
  end

  it "logs the explanation of the profile results" do
    profiler.profile("Testing") { }

    logger.messages.first.should =~ /the explanation/
  end

  it "logs results even when an error is raised" do
    begin
      profiler.profile("Testing") { raise "a problem" }
    rescue
      logger.messages.first.should =~ /the explanation/
    end
  end

  it "describes the profiled segment" do
    profiler.profile("Tested measurement") { }

    logger.messages.first.should =~ /PROFILE \[#{identifier}\] \d Tested measurement/
  end

  it "indicates the order in which segments are profiled" do
    profiler.profile("Measurement") { }
    profiler.profile("Another measurement") { }

    logger.messages[0].should =~ /1 Measurement/
    logger.messages[1].should =~ /2 Another measurement/
  end

  it "indicates the nesting of profiled segments" do
    profiler.profile("Measurement") { profiler.profile("Nested measurement") { } }
    profiler.profile("Another measurement") { profiler.profile("Another nested measurement") { } }

    logger.messages[0].should =~ /1.1 Nested measurement/
    logger.messages[1].should =~ /1 Measurement/
    logger.messages[2].should =~ /2.1 Another nested measurement/
    logger.messages[3].should =~ /2 Another measurement/
  end

  class TestLoggingProfiler < Puppet::Util::Profiler::Logging
    def start
      "the start"
    end

    def finish(context)
      "the explanation of #{context}"
    end
  end

  class SimpleLog
    attr_reader :messages

    def initialize
      @messages = []
    end

    def call(msg)
      @messages << msg
    end
  end
end

