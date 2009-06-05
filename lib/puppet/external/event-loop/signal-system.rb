## signal-system.rb --- simple intra-process signal system
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

module SignalEmitterModule
    def self.extended (object)
        if object.kind_of? Module and not object < SignalEmitter
            if object.respond_to? :fcall
                # This is the way to call private methods
                # in Ruby 1.9 as of November 16.
                object.fcall :include, SignalEmitter
            else
                object.__send__ :include, SignalEmitter
            end
        end
    end

    def define_signal (name, slot=:before, &body)
        # Can't use `define_method' and take a block pre-1.9.
        class_eval %{ def on_#{name} &block
                    add_signal_handler(:#{name}, &block) end }
        define_signal_handler(name, :before, &lambda {|*a|})
        define_signal_handler(name, :after, &lambda {|*a|})
        define_signal_handler(name, slot, &body) if block_given?
    end

    def define_signals (*names, &body)
        names.each { |x| define_signal(x, &body) }
    end

    def define_signal_handler (name, slot=:before, &body)
        case slot
        when :before
            define_protected_method "handle_#{name}", &body
        when :after
            define_protected_method "after_handle_#{name}", &body
        else
            raise ArgumentError, "invalid slot `#{slot.inspect}'; " +
                "should be `:before' or `:after'", caller(1)
        end
    end
end

# This is an old name for the same thing.
SignalEmitterClass = SignalEmitterModule

module SignalEmitter
    def self.included (includer)
        if not includer.kind_of? SignalEmitterClass
            includer.extend SignalEmitterClass
        end
    end

    def __maybe_initialize_signal_emitter
        @signal_handlers ||= Hash.new { |h, k| h[k] = Array.new }
        @allow_dynamic_signals ||= false
    end

    define_accessors :allow_dynamic_signals?

    def add_signal_handler (name, &handler)
        __maybe_initialize_signal_emitter
        @signal_handlers[name] << handler
        return handler
    end

    define_soft_aliases [:on, :on_signal] => :add_signal_handler

    def remove_signal_handler (name, handler)
        __maybe_initialize_signal_emitter
        @signal_handlers[name].delete(handler)
    end

    def __signal__ (name, *args, &block)
        __maybe_initialize_signal_emitter
        respond_to? "on_#{name}" or allow_dynamic_signals? or
        fail "undefined signal `#{name}' for #{self}:#{self.class}"
        __send__("handle_#{name}", *args, &block) if
            respond_to? "handle_#{name}"
        @signal_handlers[name].each { |x| x.call(*args, &block) }
        __send__("after_handle_#{name}", *args, &block) if
            respond_to? "after_handle_#{name}"
    end

    define_soft_alias :signal => :__signal__
end

# This module is indended to be a convenience mixin to be used by
# classes whose objects need to observe foreign signals.  That is,
# if you want to observe some signals coming from an object, *you*
# should mix in this module.
#
# You cannot use this module at two different places of the same
# inheritance chain to observe signals coming from the same object.
#
# XXX: This has not seen much use, and I'd like to provide a
#      better solution for the problem in the future.
module SignalObserver
    def __maybe_initialize_signal_observer
        @observed_signals ||= Hash.new do |signals, object|
            signals[object] = Hash.new do |handlers, name|
                handlers[name] = Array.new
            end
        end
    end

    def observe_signal (subject, name, &handler)
        __maybe_initialize_signal_observer
        @observed_signals[subject][name] << handler
        subject.add_signal_handler(name, &handler)
    end

    def map_signals (source, pairs={})
        pairs.each do |src_name, dst_name|
            observe_signal(source, src_name) do |*args|
                __signal__(dst_name, *args)
            end
        end
    end

    def absorb_signals (subject, *names)
        names.each do |name|
            observe_signal(subject, name) do |*args|
                __signal__(name, *args)
            end
        end
    end

    define_soft_aliases \
        :map_signal    => :map_signals,
        :absorb_signal => :absorb_signals

    def ignore_signal (subject, name)
        __maybe_initialize_signal_observer
        __ignore_signal_1(subject, name)
        @observed_signals.delete(subject) if
            @observed_signals[subject].empty?
    end

    def ignore_signals (subject, *names)
        __maybe_initialize_signal_observer
        names = @observed_signals[subject] if names.empty?
        names.each { |x| __ignore_signal_1(subject, x) }
    end

  private

    def __ignore_signal_1(subject, name)
        @observed_signals[subject][name].each do |handler|
            subject.remove_signal_handler(name, handler) end
        @observed_signals[subject].delete(name)
    end
end

if __FILE__ == $0
    require "test/unit"
    class SignalEmitterTest < Test::Unit::TestCase
        class X
            include SignalEmitter
            define_signal :foo
        end

        def setup
            @x = X.new
        end

        def test_on_signal
            moomin = 0
            @x.on_signal(:foo) { moomin = 1 }
            @x.signal :foo
            assert moomin == 1
        end

        def test_on_foo
            moomin = 0
            @x.on_foo { moomin = 1 }
            @x.signal :foo
            assert moomin == 1
        end

        def test_multiple_on_signal
            moomin = 0
            @x.on_signal(:foo) { moomin += 1 }
            @x.on_signal(:foo) { moomin += 2 }
            @x.on_signal(:foo) { moomin += 4 }
            @x.on_signal(:foo) { moomin += 8 }
            @x.signal :foo
            assert moomin == 15
        end

        def test_multiple_on_foo
            moomin = 0
            @x.on_foo { moomin += 1 }
            @x.on_foo { moomin += 2 }
            @x.on_foo { moomin += 4 }
            @x.on_foo { moomin += 8 }
            @x.signal :foo
            assert moomin == 15
        end
    end
end

## application-signals.rb ends here.
