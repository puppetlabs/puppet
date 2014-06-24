require 'spec_helper'
require 'puppet/util/profiler'
require 'puppet/util/profiler/around_profiler'
require 'puppet/util/profiler/aggregate'

describe Puppet::Util::Profiler::Aggregate do
  let(:logger) { AggregateSimpleLog.new }
  let(:profiler) { Puppet::Util::Profiler::Aggregate.new(logger, nil) }
  let(:profiler_mgr) do
    p = Puppet::Util::Profiler::AroundProfiler.new
    p.add_profiler(profiler)
    p
  end

  it "tracks the aggregate counts and time for the hierarchy of metrics" do
    profiler_mgr.profile("Looking up hiera data in production environment", ["function", "hiera_lookup", "production"]) { sleep 0.01 }
    profiler_mgr.profile("Looking up hiera data in test environment", ["function", "hiera_lookup", "test"]) {}
    profiler_mgr.profile("looking up stuff for compilation", ["compiler", "lookup"]) { sleep 0.01 }
    profiler_mgr.profile("COMPILING ALL OF THE THINGS!", ["compiler", "compiling"]) {}

    profiler.values["function"].count.should == 2
    profiler.values["function"].time.should be > 0
    profiler.values["function"]["hiera_lookup"].count.should == 2
    profiler.values["function"]["hiera_lookup"]["production"].count.should == 1
    profiler.values["function"]["hiera_lookup"]["test"].count.should == 1
    profiler.values["function"].time.should be >= profiler.values["function"]["hiera_lookup"]["test"].time

    profiler.values["compiler"].count.should == 2
    profiler.values["compiler"].time.should be > 0
    profiler.values["compiler"]["lookup"].count.should == 1
    profiler.values["compiler"]["compiling"].count.should == 1
    profiler.values["compiler"].time.should be >= profiler.values["compiler"]["lookup"].time

    profiler.shutdown

    logger.output.should =~ /function -> hiera_lookup: .*\(2 calls\)\nfunction -> hiera_lookup ->.*\(1 calls\)/
    logger.output.should =~ /compiler: .*\(2 calls\)\ncompiler ->.*\(1 calls\)/
  end

  it "tolerates calls to `profile` that don't include a metric id" do
    profiler_mgr.profile("yo") {}
  end

  it "supports both symbols and strings as components of a metric id" do
    profiler_mgr.profile("yo", [:foo, "bar"]) {}
  end

  class AggregateSimpleLog
    attr_reader :output

    def initialize
      @output = ""
    end

    def call(msg)
      @output << msg << "\n"
    end
  end
end
