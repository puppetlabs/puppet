#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-12.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/agent'

class AgentTestClient
    def run
        # no-op
    end
    def stop
        # no-op
    end
end

describe Puppet::Agent do
    before do
        @agent = Puppet::Agent.new(AgentTestClient)

        # So we don't actually try to hit the filesystem.
        @agent.stubs(:lock).yields
    end

    it "should set its client class at initialization" do
        Puppet::Agent.new("foo").client_class.should == "foo"
    end

    it "should include the Locker module" do
        Puppet::Agent.ancestors.should be_include(Puppet::Agent::Locker)
    end

    it "should create an instance of its client class and run it when asked to run" do
        client = mock 'client'
        AgentTestClient.expects(:new).returns client

        client.expects(:run)

        @agent.stubs(:running?).returns false
        @agent.run
    end

    it "should determine its lock file path by asking the client class" do
        AgentTestClient.expects(:lockfile_path).returns "/my/lock"
        @agent.lockfile_path.should == "/my/lock"
    end

    it "should be considered running if the lock file is locked" do
        lockfile = mock 'lockfile'

        @agent.expects(:lockfile).returns lockfile
        lockfile.expects(:locked?).returns true

        @agent.should be_running
    end

    describe "when being run" do
        before do
            @agent.stubs(:running?).returns false
        end

        it "should splay" do
            @agent.expects(:splay)
            @agent.stubs(:running?).returns false

            @agent.run
        end

        it "should do nothing if already running" do
            @agent.expects(:running?).returns true
            AgentTestClient.expects(:new).never
            @agent.run
        end

        it "should do nothing if it is in the process of stopping" do
            @agent.expects(:stopping?).returns true
            AgentTestClient.expects(:new).never
            @agent.run
        end

        it "should not fail if a client class instance cannot be created" do
            AgentTestClient.expects(:new).raises "eh"
            Puppet.expects(:err)
            @agent.run
        end

        it "should not fail if there is an exception while running its client" do
            client = AgentTestClient.new
            AgentTestClient.expects(:new).returns client
            client.expects(:run).raises "eh"
            Puppet.expects(:err)
            @agent.run
        end

        it "should use a mutex to restrict multi-threading" do
            client = AgentTestClient.new
            AgentTestClient.expects(:new).returns client

            mutex = mock 'mutex'
            @agent.expects(:sync).returns mutex

            mutex.expects(:synchronize)
            client.expects(:run).never # if it doesn't run, then we know our yield is what triggers it
            @agent.run
        end

        it "should use a filesystem lock to restrict multiple processes running the agent" do
            client = AgentTestClient.new
            AgentTestClient.expects(:new).returns client

            @agent.expects(:lock)

            client.expects(:run).never # if it doesn't run, then we know our yield is what triggers it
            @agent.run
        end

        it "should make its client instance available while running" do
            client = AgentTestClient.new
            AgentTestClient.expects(:new).returns client

            client.expects(:run).with { @agent.client.should equal(client); true }
            @agent.run
        end
    end

    describe "when splaying" do
        before do
            Puppet.settings.stubs(:value).with(:splay).returns true
            Puppet.settings.stubs(:value).with(:splaylimit).returns "10"
        end

        it "should do nothing if splay is disabled" do
            Puppet.settings.expects(:value).returns false
            @agent.expects(:sleep).never
            @agent.splay
        end

        it "should do nothing if it has already splayed" do
            @agent.expects(:splayed?).returns true
            @agent.expects(:sleep).never
            @agent.splay
        end

        it "should log that it is splaying" do
            @agent.stubs :sleep
            Puppet.expects :info
            @agent.splay
        end

        it "should sleep for a random portion of the splaylimit plus 1" do
            Puppet.settings.expects(:value).with(:splaylimit).returns "50"
            @agent.expects(:rand).with(51).returns 10
            @agent.expects(:sleep).with(10)
            @agent.splay
        end

        it "should mark that it has splayed" do
            @agent.stubs(:sleep)
            @agent.splay
            @agent.should be_splayed
        end
    end
    
    describe "when stopping" do
        it "should do nothing if already stopping" do
            @agent.expects(:stopping?).returns true
            @agent.stop
        end

        it "should stop the client if one is available and it responds to 'stop'" do
            client = AgentTestClient.new

            @agent.stubs(:client).returns client
            client.expects(:stop)
            @agent.stop
        end

        it "should mark itself as stopping while waiting for the client to stop" do
            client = AgentTestClient.new

            @agent.stubs(:client).returns client
            client.expects(:stop).with { @agent.should be_stopping; true }

            @agent.stop
        end
    end

    describe "when starting" do
        before do
            @agent.stubs(:observe_signal)
        end

        it "should create a timer with the runinterval, a tolerance of 1, and :start? set to true" do
            Puppet.settings.expects(:value).with(:runinterval).returns 5
            timer = stub 'timer', :sound_alarm => nil
            EventLoop::Timer.expects(:new).with(:interval => 5, :start? => true, :tolerance => 1).returns timer

            @agent.stubs(:run)
            @agent.start
        end

        it "should run once immediately" do
            timer = mock 'timer'
            EventLoop::Timer.expects(:new).returns timer

            timer.expects(:sound_alarm)

            @agent.start
        end

        it "should run within the block passed to the timer" do
            timer = stub 'timer', :sound_alarm => nil
            EventLoop::Timer.expects(:new).returns(timer).yields
            @agent.expects(:run)

            @agent.start
        end
    end

    describe "when restarting" do
        it "should configure itself for a delayed restart if currently running" do
            @agent.expects(:running?).returns true

            @agent.restart

            @agent.should be_needing_restart
        end

        it "should hup itself if not running" do
            @agent.expects(:running?).returns false

            Process.expects(:kill).with(:HUP, $$)

            @agent.restart
        end

        it "should turn off the needing_restart switch" do
            @agent.expects(:running?).times(2).returns(true).then.returns false

            Process.stubs(:kill)

            # First call sets up the switch
            @agent.restart

            # Second call should disable it
            @agent.restart
            @agent.should_not be_needing_restart
        end
    end
end
