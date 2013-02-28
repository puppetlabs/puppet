require 'benchmark'

module Puppet::Util::Profiler
  require 'puppet/util/profiler/measuring'
  require 'puppet/util/profiler/none'

  NONE = Puppet::Util::Profiler::None.new

  def self.current
    Thread.current[:profiler] || NONE
  end

  def self.current=(profiler)
    Thread.current[:profiler] = profiler
  end
end
