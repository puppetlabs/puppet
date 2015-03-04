require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::ObjectCounts do
  it "reports the changes in the system object counts" do
    profiler = Puppet::Util::Profiler::ObjectCounts.new(nil, nil)

    message = profiler.finish(profiler.start)

    expect(message).to match(/ T_STRING: \d+, /)
  end
end
