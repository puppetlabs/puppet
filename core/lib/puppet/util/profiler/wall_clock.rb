require 'puppet/util/profiler/logging'

# A profiler implementation that measures the number of seconds a segment of
# code takes to execute and provides a callback with a string representation of
# the profiling information.
#
# @api private
class Puppet::Util::Profiler::WallClock < Puppet::Util::Profiler::Logging
  def start
    Timer.new
  end

  def finish(context)
    context.stop
    "took #{context} seconds"
  end

  class Timer
    FOUR_DECIMAL_DIGITS = '%0.4f'

    def initialize
      @start = Time.now
    end

    def stop
      @finish = Time.now
    end

    def to_s
      format(FOUR_DECIMAL_DIGITS, @finish - @start)
    end
  end
end

