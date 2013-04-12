module Puppet::Scheduler
  class Timer
    def wait_for(seconds)
      if seconds > 0
        select([], [], [], seconds)
      end
    end

    def now
      Time.now
    end
  end
end
