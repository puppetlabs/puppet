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
    start = Time.now
    begin
      retval = yield
    ensure
      finish = Time.now
      @sequence.up
      elapsed = finish - start
      @logger.call("[#{@identifier}] #{@sequence} #{description} in #{format('%0.4f', elapsed)} seconds")
    end
    retval
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

