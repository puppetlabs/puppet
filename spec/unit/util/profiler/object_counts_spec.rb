require 'spec_helper'
require 'puppet/util/profiler'

describe Puppet::Util::Profiler::ObjectCounts do
  it "reports the changes in the system object counts" do
    pending("Can only count objects on ruby 1.9 or greater", :if => RUBY_VERSION < '1.9') do
      profiler = Puppet::Util::Profiler::ObjectCounts.new(nil, nil)

      message = profiler.finish(profiler.start)

      message.should =~ / T_STRING: \d+, /
    end
  end
end
