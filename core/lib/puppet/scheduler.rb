module Puppet::Scheduler
  require 'puppet/scheduler/job'
  require 'puppet/scheduler/splay_job'
  require 'puppet/scheduler/scheduler'
  require 'puppet/scheduler/timer'

  module_function

  def create_job(interval, splay=false, splay_limit=0, &block)
    if splay
      Puppet::Scheduler::SplayJob.new(interval, splay_limit, &block)
    else
      Puppet::Scheduler::Job.new(interval, &block)
    end
  end
end
