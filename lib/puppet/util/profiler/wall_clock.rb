# A profiler implementation that measures the number of seconds a segment of
# code takes to execute and provides a callback with a string representation of
# the profiling information.
#
# @api private
class Puppet::Util::Profiler::WallClock
  def initialize(logger, identifier)
    @logger = logger
    @identifier = identifier
    @sequence = Sequence.new
  end

  def start
    Timer.new
  end

  def finish(context)
    context.stop
    "took #{context} seconds"
  end

  def profile(description, &block)
    retval = nil
    @sequence.next
    @sequence.down
    context = start
    begin
      retval = yield
    ensure
      profile_explanation = finish(context)
      @sequence.up
      @logger.call("[#{@identifier}] #{@sequence} #{description}: #{profile_explanation}")
    end
    retval
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

  class Sequence
    INITIAL = 0
    SEPARATOR = '.'

    def initialize
      @elements = [INITIAL]
    end

    def next
      @elements[-1] += 1
    end

    def down
      @elements << INITIAL
    end

    def up
      @elements.pop
    end

    def to_s
      @elements.join(SEPARATOR)
    end
  end
end

