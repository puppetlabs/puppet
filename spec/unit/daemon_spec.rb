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

  before do
    # Forking agent not needed here
    @agent = Puppet::Agent.new(TestClient.new, false)
    @daemon = Puppet::Daemon.new
    @daemon.stubs(:close_streams).returns nil
  end

  it "should be able to manage an agent" do
    @daemon.should respond_to(:agent)
  end

  it "should be able to manage a network server" do
    @daemon.should respond_to(:server)
  end

  it "should reopen the Log logs when told to reopen logs" do
    Puppet::Util::Log.expects(:reopen)
    @daemon.reopen_logs
  end

  describe "when setting signal traps" do
    signals = {:INT => :stop, :TERM => :stop }
    signals.update({:HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs}) unless Puppet.features.microsoft_windows?
    signals.each do |signal, method|
      it "should log and call #{method} when it receives #{signal}" do
        Signal.expects(:trap).with(signal).yields

        Puppet.expects(:notice)

        @daemon.expects(method)

        @daemon.set_signal_traps
      end
    end
  end

  describe "when starting" do
    before do
      @daemon.stubs(:create_pidfile)
      @daemon.stubs(:set_signal_traps)
      @daemon.stubs(:run_event_loop)
    end

    it "should fail if it has neither agent nor server" do
      lambda { @daemon.start }.should raise_error(Puppet::DevError)
    end

    it "should create its pidfile" do
      @daemon.agent = @agent

      @daemon.expects(:create_pidfile)
      @daemon.start
    end

    it "should start its server if one is configured" do
      server = mock 'server'
      server.expects(:start)
      @daemon.stubs(:server).returns server

      @daemon.start
    end
  end

  describe "when stopping" do
    before do
      @daemon.stubs(:remove_pidfile)
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
      server = mock 'server'
      server.expects(:stop)
      @daemon.stubs(:server).returns server
      expect { @daemon.stop }.to exit_with 0
    end

    it 'should request a stop from Puppet::Application' do
      Puppet::Application.expects(:stop!)
      expect { @daemon.stop }.to exit_with 0
    end

    it "should remove its pidfile" do
      @daemon.expects(:remove_pidfile)
      expect { @daemon.stop }.to exit_with 0
    end

    it "should close all logs" do
      Puppet::Util::Log.expects(:close_all)
      expect { @daemon.stop }.to exit_with 0
    end

    it "should exit unless called with ':exit => false'" do
      expect { @daemon.stop }.to exit_with 0
    end

    it "should not exit if called with ':exit => false'" do
      @daemon.stop :exit => false
    end
  end

  describe "when creating its pidfile" do
    it "should use an exclusive mutex" do
      Puppet.run_mode.expects(:name).returns "me"
      Puppet::Util.expects(:synchronize_on).with("me",Sync::EX)
      @daemon.create_pidfile
    end

    it "should lock the pidfile using the Pidlock class" do
      pidfile = mock 'pidfile'

      Puppet.run_mode.expects(:name).returns "eh"
      Puppet[:pidfile] = make_absolute("/my/file")

      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      pidfile.expects(:lock).returns true
      @daemon.create_pidfile
    end

    it "should fail if it cannot lock" do
      pidfile = mock 'pidfile'

      Puppet.run_mode.expects(:name).returns "eh"
      Puppet[:pidfile] = make_absolute("/my/file")

      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      pidfile.expects(:lock).returns false

      lambda { @daemon.create_pidfile }.should raise_error
    end
  end

  describe "when removing its pidfile" do
    it "should use an exclusive mutex" do
      Puppet.run_mode.expects(:name).returns "me"

      Puppet::Util.expects(:synchronize_on).with("me",Sync::EX)

      @daemon.remove_pidfile
    end

    it "should do nothing if the pidfile is not present" do
      pidfile = mock 'pidfile', :unlock => false

      Puppet[:pidfile] = make_absolute("/my/file")
      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      @daemon.remove_pidfile
    end

    it "should unlock the pidfile using the Pidlock class" do
      pidfile = mock 'pidfile', :unlock => true

      Puppet[:pidfile] = make_absolute("/my/file")
      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      @daemon.remove_pidfile
    end
  end

  describe "when reloading" do
    it "should do nothing if no agent is configured" do
      @daemon.reload
    end

    it "should do nothing if the agent is running" do
      @agent.expects(:running?).returns true

      @daemon.agent = @agent

      @daemon.reload
    end

    it "should run the agent if one is available and it is not running" do
      @agent.expects(:running?).returns false
      @agent.expects :run

      @daemon.agent = @agent

      @daemon.reload
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
      @daemon.stubs(:reexec)
      @daemon.restart
    end

    it "should reexec itself if no agent is available" do
      @daemon.expects(:reexec)

      @daemon.restart
    end

    it "should reexec itself if the agent is not running" do
      @agent.expects(:running?).returns false
      @daemon.agent = @agent
      @daemon.expects(:reexec)

      @daemon.restart
    end
  end

  describe "when reexecing it self" do
    before do
      @daemon.stubs(:exec)
      @daemon.stubs(:stop)
    end

    it "should fail if no argv values are available" do
      @daemon.expects(:argv).returns nil
      lambda { @daemon.reexec }.should raise_error(Puppet::DevError)
    end

    it "should shut down without exiting" do
      @daemon.argv = %w{foo}
      @daemon.expects(:stop).with(:exit => false)

      @daemon.reexec
    end

    it "should call 'exec' with the original executable and arguments" do
      @daemon.argv = %w{foo}
      @daemon.expects(:exec).with($0 + " foo")

      @daemon.reexec
    end
  end
end
