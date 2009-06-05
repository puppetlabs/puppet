## event-loop.rb --- high-level IO multiplexer
# Copyright (C) 2005  Daniel Brockman

# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option) any
# later version.

# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.

require "puppet/external/event-loop/better-definers"
require "puppet/external/event-loop/signal-system"

require "fcntl"

class EventLoop
    include SignalEmitter

    IO_STATES = [:readable, :writable, :exceptional]

    class << self
        def default ; @default ||= new end
        def default= x ; @default = x end

        def current
            Thread.current["event-loop::current"] || default end
        def current= x
            Thread.current["event-loop::current"] = x end

        def with_current (new)
            if current == new
                yield
            else
                begin
                    old = self.current
                    self.current = new
                    yield
                ensure
                    self.current = old
                end
            end
        end

        def method_missing (name, *args, &block)
            if current.respond_to? name
                current.__send__(name, *args, &block)
            else
                super
            end
        end
    end

    define_signals :before_sleep, :after_sleep

    def initialize
        @running = false
        @awake = false
        @wakeup_time = nil
        @timers = []

        @io_arrays = [[], [], []]
        @ios = Hash.new do |h, k| raise ArgumentError,
            "invalid IO event: #{k}", caller(2) end
        IO_STATES.each_with_index { |x, i| @ios[x] = @io_arrays[i] }

        @notify_src, @notify_snk = IO.pipe

        # prevent file descriptor leaks
        @notify_src.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
        @notify_snk.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

        @notify_src.will_block = false
        @notify_snk.will_block = false

        # Each time a byte is sent through the notification pipe
        # we need to read it, or IO.select will keep returning.
        monitor_io(@notify_src, :readable)
        @notify_src.extend(Watchable)
        @notify_src.on_readable do
            begin
                @notify_src.sysread(256)
            rescue Errno::EAGAIN
                # The pipe wasn't readable after all.
            end
        end
    end

    define_opposite_accessors \
        :stopped?  => :running?,
        :sleeping? => :awake?

    def run
        if block_given?
            thread = Thread.new { run }
            yield ; quit ; thread.join
        else
            running!
            iterate while running?
        end
    ensure
        quit
    end

    def iterate (user_timeout=nil)
        t1, t2 = user_timeout, max_timeout
        timeout = t1 && t2 ? [t1, t2].min : t1 || t2
        select(timeout).zip(IO_STATES) do |ios, state|
            ios.each { |x| x.signal(state) } if ios
        end
    end

  private

    def select (timeout)
        @wakeup_time = timeout ? Time.now + timeout : nil
        # puts "waiting: #{timeout} seconds"
        signal :before_sleep ; sleeping!
        IO.select(*@io_arrays + [timeout]) || []
    ensure
        awake! ; signal :after_sleep
        @timers.each { |x| x.sound_alarm if x.ready? }
    end

  public

    def quit ; stopped! ; wake_up ; self end

    def monitoring_io? (io, event)
        @ios[event].include? io end
    def monitoring_timer? (timer)
        @timers.include? timer end

    def monitor_io (io, *events)
        for event in events do
            unless monitoring_io?(io, event)
                @ios[event] << io ; wake_up
            end
        end
    end

    def monitor_timer (timer)
        unless monitoring_timer? timer
            @timers << timer
        end
    end

    def check_timer (timer)
        wake_up if timer.end_time < @wakeup_time
    end

    def ignore_io (io, *events)
        events = IO_STATES if events.empty?
        for event in events do
            wake_up if @ios[event].delete(io)
        end
    end

    def ignore_timer (timer)
        # Don't need to wake up for this.
        @timers.delete(timer)
    end

    def max_timeout
        return nil if @timers.empty?
        [@timers.collect { |x| x.time_left }.min, 0].max
    end

    def wake_up
        @notify_snk.write('.') if sleeping?
    end
end

class Symbol
    def io_state?
        EventLoop::IO_STATES.include? self
    end
end

module EventLoop::Watchable
    include SignalEmitter

    define_signals :readable, :writable, :exceptional

    def monitor_events (*events)
        EventLoop.monitor_io(self, *events) end
    def ignore_events (*events)
        EventLoop.ignore_io(self, *events) end

    define_soft_aliases \
        :monitor_event => :monitor_events,
        :ignore_event  => :ignore_events

    def close ; super
        ignore_events end
    def close_read ; super
        ignore_event :readable end
    def close_write ; super
        ignore_event :writable end

    module Automatic
        include EventLoop::Watchable

        def add_signal_handler (name, &handler) super
            monitor_event(name) if name.io_state?
        end

        def remove_signal_handler (name, handler) super
            if @signal_handlers[name].empty?
                ignore_event(name) if name.io_state?
            end
        end
    end
end

class IO
    def on_readable &block
        extend EventLoop::Watchable::Automatic
        on_readable(&block)
    end

    def on_writable &block
        extend EventLoop::Watchable::Automatic
        on_writable(&block)
    end

    def on_exceptional &block
        extend EventLoop::Watchable::Automatic
        on_exceptional(&block)
    end

    def will_block?
        require "fcntl"
        fcntl(Fcntl::F_GETFL, 0) & Fcntl::O_NONBLOCK == 0
    end

    def will_block= (wants_blocking)
        require "fcntl"
        flags = fcntl(Fcntl::F_GETFL, 0)
        if wants_blocking
            flags &= ~Fcntl::O_NONBLOCK
        else
            flags |= Fcntl::O_NONBLOCK
        end
        fcntl(Fcntl::F_SETFL, flags)
    end
end

class EventLoop::Timer
    include SignalEmitter

    DEFAULT_INTERVAL = 0.0
    DEFAULT_TOLERANCE = 0.001

    def initialize (options={}, &handler)
        @running = false
        @start_time = nil

        if options.kind_of? Numeric
            options = { :interval => options }
        end

        if options[:interval]
            @interval = options[:interval].to_f
        else
            @interval = DEFAULT_INTERVAL
        end

        if options[:tolerance]
            @tolerance = options[:tolerance].to_f
        elsif DEFAULT_TOLERANCE < @interval
            @tolerance = DEFAULT_TOLERANCE
        else
            @tolerance = 0.0
        end

        @event_loop = options[:event_loop] || EventLoop.current

        if block_given?
            add_signal_handler(:alarm, &handler)
            start unless options[:start?] == false
        else
            start if options[:start?]
        end
    end

    define_readers :interval, :tolerance
    define_signal :alarm

    def stopped? ; @start_time == nil end
    def running? ; @start_time != nil end

    def interval= (new_interval)
        old_interval = @interval
        @interval = new_interval
        if new_interval < old_interval
            @event_loop.check_timer(self)
        end
    end

    def end_time
        @start_time + @interval end
    def time_left
        end_time - Time.now end
    def ready?
        time_left <= @tolerance end

    def restart
        @start_time = Time.now
    end

    def sound_alarm
        signal :alarm
        restart if running?
    end

    def start
        @start_time = Time.now
        @event_loop.monitor_timer(self)
    end

    def stop
        @start_time = nil
        @event_loop.ignore_timer(self)
    end
end

if __FILE__ == $0
    require "test/unit"

    class TimerTest < Test::Unit::TestCase
        def setup
            @timer = EventLoop::Timer.new(:interval => 0.001)
        end

        def test_timer
            @timer.on_alarm do
                puts "[#{@timer.time_left} seconds left after alarm]"
                EventLoop.quit
            end
            8.times do
                t0 = Time.now
                @timer.start ; EventLoop.run
                t1 = Time.now
                assert(t1 - t0 > @timer.interval - @timer.tolerance)
            end
        end
    end
end

## event-loop.rb ends here.
