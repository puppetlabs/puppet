require 'spec_helper'
require 'puppet/daemon'
require 'puppet/agent'
require 'puppet/configurer'

describe Puppet::Daemon, :unless => Puppet::Util::Platform.windows? do
  include PuppetSpec::Files

  class RecordingScheduler
    attr_reader :jobs

    def run_loop(jobs)
      @jobs = jobs
    end
  end

  let(:agent) { Puppet::Agent.new(Puppet::Configurer, false) }
  let(:server) { double("Server", :start => nil, :wait_for_shutdown => nil) }

  let(:pidfile) { double("PidFile", :lock => true, :unlock => true, :file_path => 'fake.pid') }
  let(:scheduler) { RecordingScheduler.new }

  let(:daemon) { Puppet::Daemon.new(agent, pidfile, scheduler) }

  before(:each) do
    allow(Signal).to receive(:trap)
    allow(daemon).to receive(:close_streams).and_return(nil)
  end

  it "should fail when no agent is provided" do
    expect { Puppet::Daemon.new(nil, pidfile, scheduler) }.to raise_error(Puppet::DevError)
  end

  it "should reopen the Log logs when told to reopen logs" do
    expect(Puppet::Util::Log).to receive(:reopen)
    daemon.reopen_logs
  end

  describe "when setting signal traps" do
    [:INT, :TERM].each do |signal|
      it "logs a notice and exits when sent #{signal}" do
        allow(Signal).to receive(:trap).with(signal).and_yield
        expect(Puppet).to receive(:notice).with("Caught #{signal}; exiting")
        expect(daemon).to receive(:stop)

        daemon.set_signal_traps
      end
    end

    {:HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs}.each do |signal, method|
      it "logs a notice and remembers to call #{method} when it receives #{signal}" do
        allow(Signal).to receive(:trap).with(signal).and_yield
        expect(Puppet).to receive(:notice).with("Caught #{signal}; storing #{method}")

        daemon.set_signal_traps

        expect(daemon.signals).to eq([method])
      end
    end
  end

  describe "when starting" do
    let(:reparse_run) { scheduler.jobs[0] }
    let(:agent_run) { scheduler.jobs[1] }

    before do
      allow(daemon).to receive(:set_signal_traps)
    end

    it "should create its pidfile" do
      expect(pidfile).to receive(:lock).and_return(true)
      daemon.start
    end

    it "should fail if it cannot lock" do
      expect(pidfile).to receive(:lock).and_return(false)
      expect { daemon.start }.to raise_error(RuntimeError, "Could not create PID file: #{pidfile.file_path}")
    end

    it "disables the reparse of configs if the filetimeout is 0" do
      Puppet[:filetimeout] = 0
      daemon.start
      expect(reparse_run).not_to be_enabled
    end

    it "does not splay the agent run by default" do
      daemon.start
      expect(agent_run).to be_an_instance_of(Puppet::Scheduler::Job)
    end

    describe "and calculating splay" do
      before do
        # Set file timeout so the daemon reparses
        Puppet[:filetimeout] = 1
        Puppet[:splay] = true
      end

      it "recalculates when splaylimit changes" do
        daemon.start

        Puppet[:splaylimit] = 60
        init_splay = agent_run.splay
        next_splay = init_splay + 1
        allow(agent_run).to receive(:rand).and_return(next_splay)
        reparse_run.run(Time.now)

        expect(agent_run.splay).to eq(next_splay)
      end

      it "does not change splay if splaylimit is unmodified" do
        daemon.start

        init_splay = agent_run.splay
        reparse_run.run(Time.now)

        expect(agent_run.splay).to eq(init_splay)
      end
    end
  end

  describe "when stopping" do
    before do
      allow(Puppet::Util::Log).to receive(:close_all)
      # to make the global safe to mock, set it to a subclass of itself
      stub_const('Puppet::Application', Class.new(Puppet::Application))
    end

    it 'should request a stop from Puppet::Application' do
      expect(Puppet::Application).to receive(:stop!)
      expect { daemon.stop }.to exit_with 0
    end

    it "should remove its pidfile" do
      expect(pidfile).to receive(:unlock)
      expect { daemon.stop }.to exit_with 0
    end

    it "should close all logs" do
      expect(Puppet::Util::Log).to receive(:close_all)
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
    it "should do nothing if the agent is running" do
      expect(agent).to receive(:run).with({:splay => false}).and_raise(Puppet::LockError, 'Failed to aquire lock')
      expect(Puppet).to receive(:notice).with('Not triggering already-running agent')

      daemon.reload
    end

    it "should run the agent if one is available and it is not running" do
      expect(agent).to receive(:run).with({:splay => false})
      expect(Puppet).not_to receive(:notice).with('Not triggering already-running agent')

      daemon.reload
    end
  end

  describe "when restarting" do
    before do
      stub_const('Puppet::Application', Class.new(Puppet::Application))
    end

    it 'should set Puppet::Application.restart!' do
      expect(Puppet::Application).to receive(:restart!)
      allow(daemon).to receive(:reexec)
      daemon.restart
    end

    it "should reexec itself if no agent is available" do
      expect(daemon).to receive(:reexec)
      daemon.restart
    end

    it "should reexec itself if the agent is not running" do
      expect(daemon).to receive(:reexec)
      daemon.restart
    end
  end

  describe "when reexecing it self" do
    before do
      allow(daemon).to receive(:exec)
      allow(daemon).to receive(:stop)
    end

    it "should fail if no argv values are available" do
      expect(daemon).to receive(:argv).and_return(nil)
      expect { daemon.reexec }.to raise_error(Puppet::DevError)
    end

    it "should shut down without exiting" do
      daemon.argv = %w{foo}
      expect(daemon).to receive(:stop).with({:exit => false})
      daemon.reexec
    end

    it "should call 'exec' with the original executable and arguments" do
      daemon.argv = %w{foo}
      expect(daemon).to receive(:exec).with($0 + " foo")
      daemon.reexec
    end
  end
end
