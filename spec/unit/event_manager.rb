#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

require 'puppet/event_manager'
require 'puppet/agent'

describe Puppet::EventManager do
    before do
        @manager = Puppet::EventManager.new
    end

    it "should include SignalObserver" do
        Puppet::EventManager.ancestors.should be_include(SignalObserver)
    end

    it "should should add the provided service to its list of services when a new service is added" do
        @manager.add_service("foo")
        @manager.services.should be_include("foo")
    end

    it "should create a new thread and add it to its thread list when a new thread is added" do
        Thread.expects(:new).returns "foo"
        @manager.newthread {}
        @manager.threads.should be_include("foo")
    end

    it "should stop all timers, services, and threads, then exit, when asked to shutdown" do
        @manager.expects(:stop_services)
        @manager.expects(:stop_timers)
        @manager.expects(:stop_threads)

        @manager.expects(:exit)

        @manager.shutdown
    end

    it "should tell the event loop to monitor each timer when told to start timers" do
        timer1 = mock 'timer1'
        timer2 = mock 'timer2'

        @manager.expects(:timers).returns [timer1, timer2]

        EventLoop.current.expects(:monitor_timer).with timer1
        EventLoop.current.expects(:monitor_timer).with timer2

        @manager.start_timers
    end

    it "should tell the event loop to stop monitoring each timer when told to stop timers" do
        timer1 = mock 'timer1'
        timer2 = mock 'timer2'

        @manager.expects(:timers).returns [timer1, timer2]

        EventLoop.current.expects(:ignore_timer).with timer1
        EventLoop.current.expects(:ignore_timer).with timer2

        @manager.stop_timers
    end

    it "should start all services, monitor all timers, and let the current event loop run when told to start" do
        @manager.expects(:start_services)
        @manager.expects(:start_timers)

        EventLoop.current.expects(:run)

        @manager.start
    end

    it "should reopen the Log logs when told to reopen logs" do
        Puppet::Util::Log.expects(:reopen)
        @manager.reopen_logs
    end

    describe "when adding a timer" do
        before do
            @timer = mock("timer")
            EventLoop::Timer.stubs(:new).returns @timer

            @manager.stubs(:observe_signal)
        end

        it "should create and return a new timer with the provided arguments" do
            timer = mock("timer")
            EventLoop::Timer.expects(:new).with(:foo => :bar).returns @timer

            @manager.newtimer(:foo => :bar) {}.should equal(@timer)
        end

        it "should add the timer to the list of timers" do
            @manager.newtimer(:foo => :bar) {}

            @manager.timers.should be_include(@timer)
        end

        it "should set up a signal observer for the timer" do
            @manager.expects(:observe_signal).with { |timer, signal, block| timer == @timer and signal == :alarm }

            @manager.newtimer(:foo => :bar) {}
        end
    end

    describe "when starting services" do
        before do
            @service = stub 'service', :start => nil
            @manager.stubs(:sleep)
        end

        it "should start each service" do
            service = mock 'service'
            service.expects(:start)

            @manager.add_service service

            @manager.start_services
        end

        it "should not fail if a service fails to start" do
            service = mock 'service'
            service.expects(:start).raises "eh"

            @manager.add_service @service
            @manager.add_service service

            lambda { @manager.start_services }.should_not raise_error
        end

        it "should delete failed services from its service list" do
            service = mock 'service'
            service.expects(:start).raises "eh"

            @manager.add_service @service
            @manager.add_service service

            @manager.start_services

            @manager.services.should_not be_include(service)
        end

#        it "should start each service in a separate thread" do
#            # They don't expect 'start', because we're stubbing 'newthread'
#            service1 = mock 'service1'
#            service2 = mock 'service2'
#
#            @manager.add_service service1
#            @manager.add_service service2
#
#            @manager.expects(:newthread).times(2)
#
#            @manager.start_services
#        end

        it "should exit if no services were able to be started" do
            service = mock 'service'
            service.expects(:start).raises "eh"

            @manager.add_service service

            @manager.expects(:exit).with(1)

            lambda { @manager.start_services }.should_not raise_error
        end
    end

    describe "when stopping services" do
        it "should use a timeout" do
            @manager.expects(:timeout).with(20)
            @manager.expects(:services).returns %w{foo}

            @manager.stop_services
        end

        it "should stop each service" do
            service = mock 'service'
            service.expects(:shutdown)
            @manager.expects(:services).returns [service]

            @manager.stop_services
        end

        it "should log if a timeout is encountered" do
            service = mock 'service'
            service.expects(:shutdown).raises(TimeoutError)
            @manager.expects(:services).returns [service]

            Puppet.expects(:err)

            @manager.stop_services
        end
    end

    describe "when stopping threads" do
        it "should use a timeout" do
            @manager.expects(:timeout).with(20)
            @manager.expects(:threads).returns %w{foo}

            @manager.stop_threads
        end

        it "should join each thread" do
            thread = mock 'thread'
            thread.expects(:join)
            @manager.expects(:threads).returns [thread]

            @manager.stop_threads
        end

        it "should not fail if a timeout is encountered" do
            thread = mock 'thread'
            thread.expects(:join).raises(TimeoutError)
            @manager.expects(:threads).returns [thread]

            @manager.stop_threads
        end
    end

    describe "when setting traps" do
        before do
            @manager.stubs(:trap)
        end

        {:INT => :shutdown, :TERM => :shutdown, :HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs}.each do |signal, method|
            it "should log and call #{method} when it receives #{signal}" do
                @manager.expects(:trap).with(signal).yields

                Puppet.expects(:notice)

                @manager.expects(method)

                @manager.set_traps
            end
        end
    end

    describe "when reloading" do
        it "should run all services that can be run but are not currently running" do
            service = Puppet::Agent.new(String)

            @manager.add_service service

            service.expects(:running?).returns false
            service.expects(:run)

            @manager.reload
        end

        it "should not run services that are already running" do
            service = Puppet::Agent.new(String)

            @manager.add_service service

            service.expects(:running?).returns true
            service.expects(:run).never

            @manager.reload
        end

        it "should not try to run services that cannot be run" do
            service = "string"
            @manager.add_service service

            @manager.reload
        end
    end
end
