require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::ObjectCounts, unless: Puppet::Util::Platform.jruby? do
  # ObjectSpace is not enabled by default on JRuby
  it "reports the changes in the system object counts" do
    profiler = Puppet::Util::Profiler::ObjectCounts.new(nil, nil)

    message = profiler.finish(profiler.start)

    expect(message).to match(/ T_STRING: \d+, /)
  end
end
