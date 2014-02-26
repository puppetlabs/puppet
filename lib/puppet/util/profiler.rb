require 'benchmark'

# A simple profiling callback system.
#
# @api public
module Puppet::Util::Profiler
  require 'puppet/util/profiler/wall_clock'
  require 'puppet/util/profiler/object_counts'
  require 'puppet/util/profiler/none'

  NONE = Puppet::Util::Profiler::None.new

  # Reset the profiling system to the original state
  #
  # @api private
  def self.clear
    @profiler = nil
  end

  # @return This thread's configured profiler
  # @api private
  def self.current
    @profiler || NONE
  end

  # @param profiler [#profile] A profiler for the current thread
  # @api private
  def self.current=(profiler)
    @profiler = profiler
  end

  # Profile a block of code and log the time it took to execute.
  #
  # This outputs logs entries to the Puppet masters logging destination
  # providing the time it took, a message describing the profiled code
  # and a leaf location marking where the profile method was called
  # in the profiled hierachy.
  #
  # @param message [String] A description of the profiled event
  # @param block [Block] The segment of code to profile
  # @api public
  def self.profile(message, &block)
    current.profile(message, &block)
  end
end
