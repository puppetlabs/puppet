require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::Measuring do
  let(:logger) { SimpleLog.new }
  let(:identifier) { "Profiling ID" }
  let(:profiler) { Puppet::Util::Profiler::Measuring.new(logger, identifier) }

  it "returns the value of the profiled block" do
    retval = profiler.profile("Testing") { "the return value" }

    retval.should == "the return value"
  end

  it "logs the number of seconds it took to execute the block" do
    profiler.profile("Testing") { }

    logger.messages.first.should =~ /in \d\.\d{4} seconds$/
  end

  it "describes the profiled segment" do
    profiler.profile("Tested measurement") { }

    logger.messages.first.should =~ /\[#{identifier}\] \d Tested measurement/
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
