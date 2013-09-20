class Puppet::Util::Profiler::Logging
  def initialize(logger, identifier)
    @logger = logger
    @identifier = identifier
    @sequence = Sequence.new
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
      @logger.call("PROFILE [#{@identifier}] #{@sequence} #{description}: #{profile_explanation}")
    end
    retval
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
