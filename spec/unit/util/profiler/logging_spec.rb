require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::Logging do
  let(:logger) { SimpleLog.new }
  let(:identifier) { "Profiling ID" }
  let(:logging_profiler) { TestLoggingProfiler.new(logger, identifier) }
  let(:profiler) do
    p = Puppet::Util::Profiler::AroundProfiler.new
    p.add_profiler(logging_profiler)
    p
  end

  it "logs the explanation of the profile results" do
    profiler.profile("Testing", ["test"]) { }

    logger.messages.first.should =~ /the explanation/
  end

  it "describes the profiled segment" do
    profiler.profile("Tested measurement", ["test"]) { }

    logger.messages.first.should =~ /PROFILE \[#{identifier}\] \d Tested measurement/
  end

  it "indicates the order in which segments are profiled" do
    profiler.profile("Measurement", ["measurement"]) { }
    profiler.profile("Another measurement", ["measurement"]) { }

    logger.messages[0].should =~ /1 Measurement/
    logger.messages[1].should =~ /2 Another measurement/
  end

  it "indicates the nesting of profiled segments" do
    profiler.profile("Measurement", ["measurement1"]) do
      profiler.profile("Nested measurement", ["measurement2"]) { }
    end
    profiler.profile("Another measurement", ["measurement1"]) do
      profiler.profile("Another nested measurement", ["measurement2"]) { }
    end

    logger.messages[0].should =~ /1.1 Nested measurement/
    logger.messages[1].should =~ /1 Measurement/
    logger.messages[2].should =~ /2.1 Another nested measurement/
    logger.messages[3].should =~ /2 Another measurement/
  end

  class TestLoggingProfiler < Puppet::Util::Profiler::Logging
    def do_start(metric, description)
      "the start"
    end

    def do_finish(context, metric, description)
      {:msg => "the explanation of #{context}"}
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

