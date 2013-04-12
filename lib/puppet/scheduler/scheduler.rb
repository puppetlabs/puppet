module Puppet::Scheduler
  class Scheduler
    def initialize(jobs, timer=Puppet::Scheduler::Timer.new)
      @timer = timer
      @jobs = jobs
    end

    def run_loop
      mark_start_times(@timer.now)
      while not enabled_jobs.empty?
        @timer.wait_for(min_interval_to_next_run_from(@timer.now))
        run_ready(@timer.now)
      end
    end

    private

    def enabled_jobs
      @jobs.select(&:enabled?)
    end

    def mark_start_times(start_time)
      @jobs.each do |job|
        job.start_time = start_time
      end
    end

    def min_interval_to_next_run_from(from_time)
      enabled_jobs.map do |j|
        j.interval_to_next_from(from_time)
      end.min
    end

    def run_ready(at_time)
      enabled_jobs.each do |j|
        # This check intentionally happens right before each run,
        # instead of filtering on ready schedulers, since one may adjust
        # the readiness of a later one
        if j.ready?(at_time)
          j.run(at_time)
        end
      end
    end
  end
end
