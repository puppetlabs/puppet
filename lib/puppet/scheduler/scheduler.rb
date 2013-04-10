module Puppet::Scheduler
  class Scheduler
    def initialize(jobs, timer=Puppet::Scheduler::Timer.new)
      @timer = timer
      @jobs = jobs
    end

    def run_ready
      enabled_jobs.each do |j|
        # This check intentionally happens right before each run,
        # instead of filtering on ready schedulers, since one may adjust
        # the readiness of a later one
        if j.ready?(@now)
          j.run(@now)
        end
      end
    end

    def run_once
      @timer.wait_for(interval_to_next_run)
      @now = @timer.now
      run_ready
    end

    def run_loop
      @now = @timer.now
      mark_start_times
      while not enabled_jobs.empty?
        run_once
      end
    end

    private

    def enabled_jobs
      @jobs.select(&:enabled?)
    end

    def mark_start_times
      @jobs.each do |job|
        job.start_time = @now
      end
    end

    def interval_to_next_run
      enabled_jobs.map do |j|
        j.interval_to_next_from(@now)
      end.min
    end
  end
end
