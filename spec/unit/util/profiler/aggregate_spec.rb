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

    expect(profiler.values["function"].count).to eq(2)
    expect(profiler.values["function"].time).to be > 0
    expect(profiler.values["function"]["hiera_lookup"].count).to eq(2)
    expect(profiler.values["function"]["hiera_lookup"]["production"].count).to eq(1)
    expect(profiler.values["function"]["hiera_lookup"]["test"].count).to eq(1)
    expect(profiler.values["function"].time).to be >= profiler.values["function"]["hiera_lookup"]["test"].time

    expect(profiler.values["compiler"].count).to eq(2)
    expect(profiler.values["compiler"].time).to be > 0
    expect(profiler.values["compiler"]["lookup"].count).to eq(1)
    expect(profiler.values["compiler"]["compiling"].count).to eq(1)
    expect(profiler.values["compiler"].time).to be >= profiler.values["compiler"]["lookup"].time

    profiler.shutdown

    expect(logger.output).to match(/function -> hiera_lookup: .*\(2 calls\)\nfunction -> hiera_lookup ->.*\(1 calls\)/)
    expect(logger.output).to match(/compiler: .*\(2 calls\)\ncompiler ->.*\(1 calls\)/)
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
