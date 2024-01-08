# frozen_string_literal: true

module Puppet::Scheduler
  require_relative 'scheduler/job'
  require_relative 'scheduler/splay_job'
  require_relative 'scheduler/scheduler'
  require_relative 'scheduler/timer'

  module_function

  def create_job(interval, splay = false, splay_limit = 0, &block)
    if splay
      Puppet::Scheduler::SplayJob.new(interval, splay_limit, &block)
    else
      Puppet::Scheduler::Job.new(interval, &block)
    end
  end
end
