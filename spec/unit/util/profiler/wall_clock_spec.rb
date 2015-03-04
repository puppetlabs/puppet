require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::WallClock do

  it "logs the number of seconds it took to execute the segment" do
    profiler = Puppet::Util::Profiler::WallClock.new(nil, nil)

    message = profiler.do_finish(profiler.start(["foo", "bar"], "Testing"), ["foo", "bar"], "Testing")[:msg]

    expect(message).to match(/took \d\.\d{4} seconds/)
  end
end
