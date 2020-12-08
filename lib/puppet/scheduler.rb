module Puppet::Scheduler
  require_relative '../puppet/scheduler/job'
  require_relative '../puppet/scheduler/splay_job'
  require_relative '../puppet/scheduler/scheduler'
  require_relative '../puppet/scheduler/timer'

  module_function

  def create_job(interval, splay=false, splay_limit=0, &block)
    if splay
      Puppet::Scheduler::SplayJob.new(interval, splay_limit, &block)
    else
      Puppet::Scheduler::Job.new(interval, &block)
    end
  end
end
