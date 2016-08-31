#!/usr/bin/env rspec
require 'spec_helper'
require 'timeout'
require 'puppet/daemon'

describe Puppet::Daemon do
  include PuppetSpec::Files

  let :daemon do Puppet::Daemon.new end

  it "should be able to manage an agent" do
    daemon.should respond_to(:agent)
  end

  it "should be able to manage a network server" do
    daemon.should respond_to(:server)
  end

  it "should reopen the Log logs when told to reopen logs" do
    Puppet::Util::Log.expects(:reopen)
    daemon.reopen_logs
  end

  describe "when setting signal traps" do
    signals = {:INT => :stop, :TERM => :stop }
    signals.update({:HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs}) unless Puppet.features.microsoft_windows?
    signals.each do |signal, method|
      it "should log and call #{method} when it receives #{signal}" do
        Signal.expects(:trap).with(signal).yields

        Puppet.expects(:notice)

        daemon.expects(method)

        daemon.set_signal_traps
      end
    end
  end

  describe "when starting" do
    before do
      daemon.stubs(:create_pidfile)
      daemon.stubs(:set_signal_traps)
      daemon.stubs(:run_event_loop)
    end

    it "should fail if it has neither agent nor server" do
      lambda { daemon.start }.should raise_error(Puppet::DevError)
    end

    it "should create its pidfile" do
      daemon.stubs(:agent).returns stub('agent', :start => nil)
      daemon.expects(:create_pidfile)
      daemon.start
    end

    it "should start its server if one is configured" do
      server = mock 'server'
      server.expects(:start)
      daemon.stubs(:server).returns server

      daemon.start
    end
  end

  describe "when stopping" do
    before do
      daemon.stubs(:remove_pidfile)
      Puppet::Util::Log.stubs(:close_all)
      # to make the global safe to mock, set it to a subclass of itself,
      # then restore it in an after pass
      with_verbose_disabled { Puppet::Application = Class.new(Puppet::Application) }
    end

    after do
      # restore from the superclass so we lose the stub garbage
      with_verbose_disabled { Puppet::Application = Puppet::Application.superclass }
    end

    it "should stop its server if one is configured" do
      server = mock 'server'
      server.expects(:stop)
      daemon.stubs(:server).returns server
      expect { daemon.stop }.to exit_with 0
    end

    it 'should request a stop from Puppet::Application' do
      Puppet::Application.expects(:stop!)
      expect { daemon.stop }.to exit_with 0
    end

    it "should remove its pidfile" do
      daemon.expects(:remove_pidfile)
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

  describe "when creating its pidfile" do
    it "should use an exclusive mutex" do
      Puppet.settings.expects(:value).with(:name).returns "me"
      Puppet::Util.expects(:synchronize_on).with("me",Sync::EX)
      daemon.create_pidfile
    end

    it "should lock the pidfile using the Pidlock class" do
      pidfile = mock 'pidfile'

      Puppet.settings.stubs(:value).with(:name).returns "eh"
      Puppet.settings.expects(:value).with(:pidfile).returns make_absolute("/my/file")

      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      pidfile.expects(:lock).returns true
      daemon.create_pidfile
    end

    it "should fail if it cannot lock" do
      pidfile = mock 'pidfile'

      Puppet.settings.stubs(:value).with(:name).returns "eh"
      Puppet.settings.stubs(:value).with(:pidfile).returns make_absolute("/my/file")

      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      pidfile.expects(:lock).returns false

      lambda { daemon.create_pidfile }.should raise_error
    end
  end

  describe "when removing its pidfile" do
    it "should use an exclusive mutex" do
      Puppet.settings.expects(:value).with(:name).returns "me"

      Puppet::Util.expects(:synchronize_on).with("me",Sync::EX)

      daemon.remove_pidfile
    end

    it "should do nothing if the pidfile is not present" do
      pidfile = mock 'pidfile', :unlock => false

      Puppet[:pidfile] = make_absolute("/my/file")
      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      daemon.remove_pidfile
    end

    it "should unlock the pidfile using the Pidlock class" do
      pidfile = mock 'pidfile', :unlock => true

      Puppet[:pidfile] = make_absolute("/my/file")
      Puppet::Util::Pidlock.expects(:new).with(make_absolute("/my/file")).returns pidfile

      daemon.remove_pidfile
    end
  end

  describe "when reloading" do
    it "should do nothing if no agent is configured" do
      daemon.reload
    end

    it "should do nothing if the agent is running" do
      agent = mock 'agent'
      agent.expects(:running?).returns true

      daemon.stubs(:agent).returns agent

      daemon.reload
    end

    it "should run the agent if one is available and it is not running" do
      agent = mock 'agent'
      agent.expects(:running?).returns false
      agent.expects :run

      daemon.stubs(:agent).returns agent

      daemon.reload
    end
  end

  describe "when restarting" do
    before do
      with_verbose_disabled { Puppet::Application = Class.new(Puppet::Application) }
    end

    after do
      with_verbose_disabled { Puppet::Application = Puppet::Application.superclass }
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
      agent = mock 'agent'
      agent.expects(:running?).returns false
      daemon.stubs(:agent).returns agent
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
      lambda { daemon.reexec }.should raise_error(Puppet::DevError)
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

  describe "#run_event_loop" do
    describe "with an agent" do
      let :runinterval do 5 end

      before :each do
        daemon.agent = stub('agent', :run => nil)
        Puppet[:splaylimit]  = 3
        Puppet[:runinterval] = runinterval
        Puppet[:filetimeout] = 30

        # Eliminate randomness from these tests, so that we are testing a
        # consistent universe all the time.
        Time.stubs(:now).returns(Time.at(1000))
        daemon.stubs(:rand).returns(1)
      end

      it "should run the agent at runinterval when splay is off" do
        Puppet[:splay] = false

        # This is not actually awesome.
        daemon.expects(:select).with([], [], [], 5).throws(:success)
        Timeout::timeout(1) do
          catch :success do
            daemon.run_event_loop
          end
        end
      end

      it "should run the agent later when splay is on" do
        Puppet[:splay] = true

        daemon.expects(:select).with {|_,_,_,time| time > runinterval }.throws(:success)
        Timeout::timeout(1) do
          catch :success do
            daemon.run_event_loop
          end
        end
      end

      context "#next_agent_run_time" do
        it "the second and later agent runs should be based off splayed first run time" do
          Puppet[:splay] = true
          daemon.send(:next_agent_run_time, 1000).should == 1006 # one second random splay
          daemon.send(:next_agent_run_time, 1007).should == 1011 # ...and include splay
          daemon.send(:next_agent_run_time, 1012).should == 1016
        end

        it "should return nil (don't run) if no agent is present" do
          daemon.agent = nil
          daemon.send(:next_agent_run_time, 1000).should be_nil
          # ...and it should *stay* nil
          daemon.send(:next_agent_run_time, 1000).should be_nil
        end

        it "should always return now if timeout is zero" do
          Puppet[:runinterval] = 0
          daemon.send(:next_agent_run_time, 0).should == 0
          daemon.send(:next_agent_run_time, 1000).should == 1000
          daemon.send(:next_agent_run_time, 1001).should == 1001
          daemon.send(:next_agent_run_time, 1002).should == 1002
        end

        it "should return a time in the future even if more than one runinterval passed" do
          Puppet[:runinterval] = 5
          daemon.send(:next_agent_run_time, 1000).should == 1005
          # we skip the run at 1010.
          daemon.send(:next_agent_run_time, 1011).should == 1015
          # ...and now skip a whole bunch, just in case.
          daemon.send(:next_agent_run_time, 50001).should == 50005
        end

        it "should adapt to changes in runinterval" do
          Puppet[:runinterval] = 5
          daemon.send(:next_agent_run_time, 1000).should == 1005
          daemon.send(:next_agent_run_time, 1006).should == 1010
          Puppet[:runinterval] = 10
          daemon.send(:next_agent_run_time, 1011).should == 1020
          Puppet[:runinterval] = 5
          daemon.send(:next_agent_run_time, 1021).should == 1025
        end
      end

      context "#next_reparse_time" do
        [0, -1, -(2**32 - 1)].each do |input|
          it "should not run (return nil) if timeout is #{input}" do
            Puppet[:filetimeout] = input
            daemon.send(:next_reparse_time, 1000).should == nil
          end
        end

        it "should run every filetimeout interval" do
          Puppet[:filetimeout] = 5
          daemon.send(:next_reparse_time, 1000).should == 1005
          daemon.send(:next_reparse_time, 1002).should == 1005
          daemon.send(:next_reparse_time, 1006).should == 1010
          daemon.send(:next_reparse_time, 1011).should == 1015
        end

        it "should adapt to changes in the filetimout setting" do
          Puppet[:filetimeout] = 5
          daemon.send(:next_reparse_time, 1000).should == 1005
          daemon.send(:next_reparse_time, 1006).should == 1010
          Puppet[:filetimeout] = 10
          daemon.send(:next_reparse_time, 1011).should == 1020
          daemon.send(:next_reparse_time, 1016).should == 1020
          daemon.send(:next_reparse_time, 1021).should == 1030
          Puppet[:filetimeout] = 5
          daemon.send(:next_reparse_time, 1031).should == 1035
        end
      end
    end
  end
end
