# frozen_string_literal: true

module Puppet::Scheduler
  class SplayJob < Job
    attr_reader :splay, :splay_limit

    def initialize(run_interval, splay_limit, &block)
      @splay, @splay_limit = calculate_splay(splay_limit)
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

    # Recalculates splay.
    #
    # @param splay_limit [Integer] the maximum time (in seconds) to delay before an agent's first run.
    # @return @splay [Integer] a random integer less than or equal to the splay limit that represents the seconds to
    # delay before next agent run.
    def splay_limit=(splay_limit)
      if @splay_limit != splay_limit
        @splay, @splay_limit = calculate_splay(splay_limit)
      end
    end

    private

    def calculate_splay(limit)
      [rand(limit + 1), limit]
    end
  end
end
