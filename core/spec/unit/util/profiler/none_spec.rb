require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::None do
  let(:profiler) { Puppet::Util::Profiler::None.new }

  it "returns the value of the profiled block" do
    retval = profiler.profile("Testing") { "the return value" }

    retval.should == "the return value"
  end
end
