module Puppet::Scheduler
  class Job
    attr_reader :run_interval
    attr_accessor :last_run
    attr_accessor :start_time

    def initialize(run_interval, &block)
      self.run_interval = run_interval
      @last_run = nil
      @run_proc = block
      @enabled = true
    end

    def run_interval=(interval)
      @run_interval = [interval, 0].max
    end

    def ready?(time)
      if @last_run
        @last_run + @run_interval <= time
      else
        true
      end
    end

    def enabled?
      @enabled
    end

    def enable
      @enabled = true
    end

    def disable
      @enabled = false
    end

    def interval_to_next_from(time)
      if ready?(time)
        0
      else
        @run_interval - (time - @last_run)
      end
    end

    def run(now)
      @last_run = now
      if @run_proc
        @run_proc.call(self)
      end
    end
  end
end
