module Puppet::Scheduler
  class Scheduler
    def initialize(jobs, timer=Puppet::Scheduler::Timer.new)
      @timer = timer
      @jobs = jobs
    end

    def interval_to_next_run
      now = @timer.now
      @jobs.select(&:enabled?).map do |j|
        j.interval_to_next_from(now)
      end.min
    end

    def run_ready
      @jobs.each do |j|
        # This check intentionally happens right before each run,
        # instead of filtering on ready schedulers, since one may adjust
        # the readiness of a later one
        now = @timer.now
        if j.enabled? and j.ready?(now)
          j.run(now)
        end
      end
    end

    def run_once
      @timer.wait_for(interval_to_next_run)
      run_ready
    end

    def run_loop
      loop do
        run_once
      end
    end
  end
end
