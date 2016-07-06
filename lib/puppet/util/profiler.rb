require 'benchmark'

# A simple profiling callback system.
#
# @api public
module Puppet::Util::Profiler
  require 'puppet/util/profiler/wall_clock'
  require 'puppet/util/profiler/object_counts'
  require 'puppet/util/profiler/around_profiler'

  @profiler = Puppet::Util::Profiler::AroundProfiler.new

  # Reset the profiling system to the original state
  #
  # @api private
  def self.clear
    @profiler.clear
  end

  # Retrieve the current list of profilers
  #
  # @api private
  def self.current
    @profiler.current
  end

  # @param profiler [#profile] A profiler for the current thread
  # @api private
  def self.add_profiler(profiler)
    @profiler.add_profiler(profiler)
  end

  # @param profiler [#profile] A profiler to remove from the current thread
  # @api private
  def self.remove_profiler(profiler)
    @profiler.remove_profiler(profiler)
  end

  # Profile a block of code and log the time it took to execute.
  #
  # This outputs logs entries to the Puppet masters logging destination
  # providing the time it took, a message describing the profiled code
  # and a leaf location marking where the profile method was called
  # in the profiled hierarchy.
  #
  # @param message [String] A description of the profiled event
  # @param metric_id [Array] A list of strings making up the ID of a metric to profile
  # @param block [Block] The segment of code to profile
  # @api public
  def self.profile(message, metric_id, &block)
    @profiler.profile(message, metric_id, &block)
  end
end
