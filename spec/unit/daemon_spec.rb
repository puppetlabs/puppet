#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/daemon'
require 'puppet/agent'

def without_warnings
  flag = $VERBOSE
  $VERBOSE = nil
  yield
  $VERBOSE = flag
end

class TestClient
  def lockfile_path
    "/dev/null"
  end
end

describe Puppet::Daemon, :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  class RecordingScheduler
    attr_reader :jobs

    def run_loop(jobs)
      @jobs = jobs
    end
  end

  let(:agent) { Puppet::Agent.new(TestClient.new, false) }
  let(:server) { stub("Server", :start => nil, :wait_for_shutdown => nil) }

  let(:pidfile) { stub("PidFile", :lock => true, :unlock => true, :file_path => 'fake.pid') }
  let(:scheduler) { RecordingScheduler.new }

  let(:daemon) { Puppet::Daemon.new(pidfile, scheduler) }

  before(:each) do
    Signal.stubs(:trap)
    daemon.stubs(:close_streams).returns nil
  end

  it "should reopen the Log logs when told to reopen logs" do
    Puppet::Util::Log.expects(:reopen)
    daemon.reopen_logs
  end

  describe "when setting signal traps" do
    [:INT, :TERM].each do |signal|
      it "logs a notice and exits when sent #{signal}" do
        Signal.stubs(:trap).with(signal).yields
        Puppet.expects(:notice).with("Caught #{signal}; exiting")
        daemon.expects(:stop)

        daemon.set_signal_traps
      end
    end

    {:HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs}.each do |signal, method|
      it "logs a notice and remembers to call #{method} when it receives #{signal}" do
        Signal.stubs(:trap).with(signal).yields
        Puppet.expects(:notice).with("Caught #{signal}; storing #{method}")

        daemon.set_signal_traps

        expect(daemon.signals).to eq([method])
      end
    end
  end

  describe "when starting" do
    before do
      daemon.stubs(:set_signal_traps)
    end

    it "should fail if it has neither agent nor server" do
      expect { daemon.start }.to raise_error(Puppet::DevError)
    end

    it "should create its pidfile" do
      pidfile.expects(:lock).returns(true)

      daemon.agent = agent
      daemon.start
    end

    it "should fail if it cannot lock" do
      pidfile.expects(:lock).returns(false)
      daemon.agent = agent

      expect { daemon.start }.to raise_error(RuntimeError, "Could not create PID file: #{pidfile.file_path}")
    end

    it "should start its server if one is configured" do
      daemon.server = server

      server.expects(:start)

      daemon.start
    end

    it "disables the reparse of configs if the filetimeout is 0" do
      Puppet[:filetimeout] = 0
      daemon.agent = agent

      daemon.start

      expect(scheduler.jobs[0]).not_to be_enabled
    end

    it "disables the agent run when there is no agent" do
      Puppet[:filetimeout] = 0
      daemon.server = server

      daemon.start

      expect(scheduler.jobs[1]).not_to be_enabled
    end

    it "waits for the server to shutdown when there is one" do
      daemon.server = server

      server.expects(:wait_for_shutdown)

      daemon.start
    end

    it "waits for the server to shutdown when there is one" do
      daemon.server = server

      server.expects(:wait_for_shutdown)

      daemon.start
    end
  end

  describe "when stopping" do
    before do
      Puppet::Util::Log.stubs(:close_all)
      # to make the global safe to mock, set it to a subclass of itself,
      # then restore it in an after pass
      without_warnings { Puppet::Application = Class.new(Puppet::Application) }
    end

    after do
      # restore from the superclass so we lose the stub garbage
      without_warnings { Puppet::Application = Puppet::Application.superclass }
    end

    it "should stop its server if one is configured" do
      server.expects(:stop)

      daemon.server = server

      expect { daemon.stop }.to exit_with 0
    end

    it 'should request a stop from Puppet::Application' do
      Puppet::Application.expects(:stop!)
      expect { daemon.stop }.to exit_with 0
    end

    it "should remove its pidfile" do
      pidfile.expects(:unlock)

      expect { daemon.stop }.to exit_with 0
    end

    it "should close all logs" do
      Puppet::Util::Log.expects(:close_all)
      expect { daemon.stop }.to exit_with 0
    end

    it "should exit unless called with ':exit => false'" do
      expect { daemon.stop }.to exit_with 0
    end

    it "should not exit if called with ':exit => false'" do
      daemon.stop :exit => false
    end
  end

  describe "when reloading" do
    it "should do nothing if no agent is configured" do
      daemon.reload
    end

    it "should do nothing if the agent is running" do
      agent.expects(:run).with({:splay => false}).raises Puppet::LockError, 'Failed to aquire lock'
      Puppet.expects(:notice).with('Not triggering already-running agent')

      daemon.agent = agent

      daemon.reload
    end

    it "should run the agent if one is available and it is not running" do
      agent.expects(:run).with({:splay => false})
      Puppet.expects(:notice).with('Not triggering already-running agent').never

      daemon.agent = agent

      daemon.reload
    end
  end

  describe "when restarting" do
    before do
      without_warnings { Puppet::Application = Class.new(Puppet::Application) }
    end

    after do
      without_warnings { Puppet::Application = Puppet::Application.superclass }
    end

    it 'should set Puppet::Application.restart!' do
      Puppet::Application.expects(:restart!)
      daemon.stubs(:reexec)
      daemon.restart
    end

    it "should reexec itself if no agent is available" do
      daemon.expects(:reexec)

      daemon.restart
    end

    it "should reexec itself if the agent is not running" do
      agent.expects(:running?).returns false
      daemon.agent = agent
      daemon.expects(:reexec)

      daemon.restart
    end
  end

  describe "when reexecing it self" do
    before do
      daemon.stubs(:exec)
      daemon.stubs(:stop)
    end

    it "should fail if no argv values are available" do
      daemon.expects(:argv).returns nil
      expect { daemon.reexec }.to raise_error(Puppet::DevError)
    end

    it "should shut down without exiting" do
      daemon.argv = %w{foo}
      daemon.expects(:stop).with(:exit => false)

      daemon.reexec
    end

    it "should call 'exec' with the original executable and arguments" do
      daemon.argv = %w{foo}
      daemon.expects(:exec).with($0 + " foo")

      daemon.reexec
    end
  end
end
