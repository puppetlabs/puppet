require 'puppet/util/profiler/logging'

# A profiler implementation that measures the number of seconds a segment of
# code takes to execute and provides a callback with a string representation of
# the profiling information.
#
# @api private
class Puppet::Util::Profiler::WallClock < Puppet::Util::Profiler::Logging
  def do_start(description, metric_id)
    Timer.new
  end

  def do_finish(context, description, metric_id)
    {:time => context.stop,
     :msg => "took #{context} seconds"}
  end

  class Timer
    FOUR_DECIMAL_DIGITS = '%0.4f'

    def initialize
      @start = Time.now
    end

    def stop
      @time = Time.now - @start
      @time
    end

    def to_s
      format(FOUR_DECIMAL_DIGITS, @time)
    end
  end
end

