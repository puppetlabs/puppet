require 'benchmark'

# A simple profiling callback system.
#
# @api private
module Puppet::Util::Profiler
  require 'puppet/util/profiler/wall_clock'
  require 'puppet/util/profiler/object_counts'
  require 'puppet/util/profiler/none'

  NONE = Puppet::Util::Profiler::None.new

  # @returns This thread's configured profiler
  def self.current
    Thread.current[:profiler] || NONE
  end

  # @param profiler [#profile] A profiler for the current thread
  def self.current=(profiler)
    Thread.current[:profiler] = profiler
  end

  # @param message [String] A description of the profiled event
  # @param block [Block] The segment of code to profile
  def self.profile(message, &block)
    current.profile(message, &block)
  end
end
