# frozen_string_literal: true

require_relative '../../../puppet/util/profiler/logging'

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
    { :time => context.stop,
      :msg => _("took %{context} seconds") % { context: context } }
  end

  class Timer
    FOUR_DECIMAL_DIGITS = '%0.4f'

    def initialize
      @start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)
    end

    def stop
      @time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second) - @start
      @time
    end

    def to_s
      format(FOUR_DECIMAL_DIGITS, @time)
    end
  end
end
