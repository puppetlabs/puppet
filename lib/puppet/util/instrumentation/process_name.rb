require 'puppet'
require 'puppet/util/instrumentation'

module Puppet::Util::Instrumentation
  class ProcessName

    # start scrolling when process name is longer than
    SCROLL_LENGTH = 50

    @active = false
    class << self
      attr_accessor :active, :reason
    end

    trap(:QUIT) do
      active? ? disable : enable
    end

    def self.active?
      !! @active
    end

    def self.enable
      mutex.synchronize do
        Puppet.info("Process Name instrumentation is enabled")
        @active = true
        @x = 0
        setproctitle
      end
    end

    def self.disable
      mutex.synchronize do
        Puppet.info("Process Name instrumentation is disabled")
        @active = false
        $0 = @oldname
      end
    end

    def self.instrument(activity)
      # inconditionnally start the scroller thread here
      # because it doesn't seem possible to start a new thrad
      # from the USR2 signal handler
      @scroller ||= Thread.new do
        loop do
          scroll if active?
          sleep 1
        end
      end

      push_activity(Thread.current, activity)
      yield
    ensure
      pop_activity(Thread.current)
    end

    def self.setproctitle
      @oldname ||= $0
      $0 = "#{base}: " + rotate(process_name,@x) if active?
    end

    def self.push_activity(thread, activity)
      mutex.synchronize do
        @reason ||= {}
        @reason[thread] ||= []
        @reason[thread].push(activity)
        setproctitle
      end
    end

    def self.pop_activity(thread)
      mutex.synchronize do
        @reason[thread].pop
        if @reason[thread].empty?
          @reason.delete(thread)
        end
        setproctitle
      end
    end

    def self.process_name
      out = (@reason || {}).inject([]) do |out, reason|
        out << "#{thread_id(reason[0])} #{reason[1].join(',')}"
      end
      out.join(' | ')
    end

    # certainly non-portable
    def self.thread_id(thread)
      thread.inspect.gsub(/^#<.*:0x([a-f0-9]+) .*>$/, '\1')
    end

    def self.rotate(string, steps)
      steps ||= 0
      if string.length > 0 && steps > 0
        steps = steps % string.length
        return string[steps..string.length].concat " -- #{string[0..(steps-1)]}"
      end
      string
    end

    def self.base
      basename = case Puppet.run_mode.name
      when :master
        "master"
      when :agent
        "agent"
      else
        "puppet"
      end
    end

    def self.mutex
      #Thread.exclusive {
        @mutex ||= Sync.new
      #}
      @mutex
    end

    def self.scroll
      return if process_name.length < SCROLL_LENGTH
      mutex.synchronize do
        setproctitle
        @x += 1
      end
    end

  end
end