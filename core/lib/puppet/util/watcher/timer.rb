class Puppet::Util::Watcher::Timer
  attr_reader :timeout

  def initialize(timeout)
    @timeout = timeout
  end

  def start
    @start_time = now
  end

  def expired?
    (now - @start_time) >= @timeout
  end

  def now
    Time.now.to_i
  end
end
