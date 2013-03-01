# A profiler implementation that measures the number of seconds a segment of
# code takes to execute and provides a callback with a string representation of
# the profiling information.
#
# @api private
class Puppet::Util::Profiler::Measuring
  def initialize(logger, identifier)
    @logger = logger
    @identifier = identifier
    @sequence = Sequence.new
  end

  def profile(description, &block)
    retval = nil
    @sequence.next
    @sequence.down
    timer = Timer.new
    begin
      retval = yield
    ensure
      timer.stop
      @sequence.up
      @logger.call("[#{@identifier}] #{@sequence} #{description} in #{timer} seconds")
    end
    retval
  end

  class Timer
    def initialize
      @start = Time.now
    end

    def stop
      @finish = Time.now
    end

    def to_s
      format('%0.4f', @finish - @start)
    end
  end

  class Sequence
    INITIAL = 0

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
      @elements.join('.')
    end
  end
end

