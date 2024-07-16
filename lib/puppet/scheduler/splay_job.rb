module Puppet::Scheduler
  class SplayJob < Job
    attr_reader :splay

    def initialize(run_interval, splay_limit, &block)
      @splay = calculate_splay(splay_limit)
      super(run_interval, &block)
    end

    def interval_to_next_from(time)
      if last_run
        super
      else
        (start_time + splay) - time
      end
    end

    def ready?(time)
      if last_run
        super
      else
        start_time + splay <= time
      end
    end

    private

    def calculate_splay(limit)
      rand(limit + 1)
    end
  end
end
