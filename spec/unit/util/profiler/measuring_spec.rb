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

  it "logs at debug level the number of seconds it took to execute the block" do
    profiler.profile("Testing") { }

    logger.debugs.first.should =~ /in \d\.\d{4} seconds$/
  end

  it "describes the profiled segment" do
    profiler.profile("Tested measurement") { }

    logger.debugs.first.should =~ /\[#{identifier}\] Tested measurement/
  end

  it "indicates the order in which segments are profiled" do
    profiler.profile("Measurement") { }
    profiler.profile("Another measurement") { }

    logger.debugs[0].should =~ /^1 \[#{identifier}\] Measurement/
    logger.debugs[1].should =~ /^2 \[#{identifier}\] Another measurement/
  end

  it "indicates the nesting of profiled segments" do
    profiler.profile("Measurement") { profiler.profile("Nested measurement") { } }
    profiler.profile("Another measurement") { profiler.profile("Another nested measurement") { } }

    logger.debugs[0].should =~ /^1.1 \[#{identifier}\] Nested measurement/
    logger.debugs[1].should =~ /^1 \[#{identifier}\] Measurement/
    logger.debugs[2].should =~ /^2.1 \[#{identifier}\] Another nested measurement/
    logger.debugs[3].should =~ /^2 \[#{identifier}\] Another measurement/
  end

  class SimpleLog
    attr_reader :debugs

    def initialize
      @debugs = []
    end

    def debug(msg)
      @debugs << msg
    end
  end
end
