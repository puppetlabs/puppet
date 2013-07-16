module Puppet::Scheduler
  class Scheduler
    def initialize(timer=Puppet::Scheduler::Timer.new)
      @timer = timer
    end

    def run_loop(jobs)
      mark_start_times(jobs, @timer.now)
      while not enabled(jobs).empty?
        @timer.wait_for(min_interval_to_next_run_from(jobs, @timer.now))
        run_ready(jobs, @timer.now)
      end
    end

    private

    def enabled(jobs)
      jobs.select(&:enabled?)
    end

    def mark_start_times(jobs, start_time)
      jobs.each do |job|
        job.start_time = start_time
      end
    end

    def min_interval_to_next_run_from(jobs, from_time)
      enabled(jobs).map do |j|
        j.interval_to_next_from(from_time)
      end.min
    end

    def run_ready(jobs, at_time)
      enabled(jobs).each do |j|
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
