#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/agent'
require 'puppet/configurer'

class AgentTestClient
  def run
    # no-op
  end
  def stop
    # no-op
  end
end

def without_warnings
  flag = $VERBOSE
  $VERBOSE = nil
  yield
  $VERBOSE = flag
end

describe Puppet::Agent do
  before do
    Puppet::Status.indirection.stubs(:find).returns Puppet::Status.new("version" => Puppet.version)

    @agent = Puppet::Agent.new(AgentTestClient, false)

    # So we don't actually try to hit the filesystem.
    @agent.stubs(:lock).yields

    # make Puppet::Application safe for stubbing; restore in an :after block; silence warnings for this.
    without_warnings { Puppet::Application = Class.new(Puppet::Application) }
    Puppet::Application.stubs(:clear?).returns(true)
    Puppet::Application.class_eval do
      class << self
        def controlled_run(&block)
          block.call
        end
      end
    end
  end

  after do
    # restore Puppet::Application from stub-safe subclass, and silence warnings
    without_warnings { Puppet::Application = Puppet::Application.superclass }
  end

  it "should set its client class at initialization" do
    expect(Puppet::Agent.new("foo", false).client_class).to eq("foo")
  end

  it "should include the Locker module" do
    expect(Puppet::Agent.ancestors).to be_include(Puppet::Agent::Locker)
  end

  it "should create an instance of its client class and run it when asked to run" do
    client = mock 'client'
    AgentTestClient.expects(:new).returns client

    client.expects(:run)

    @agent.stubs(:disabled?).returns false
    @agent.run
  end

  it "should initialize the client's transaction_uuid if passed as a client_option" do
    client = mock 'client'
    transaction_uuid = 'foo'
    AgentTestClient.expects(:new).with(transaction_uuid, nil).returns client

    client.expects(:run)

    @agent.stubs(:disabled?).returns false
    @agent.run(:transaction_uuid => transaction_uuid)
  end

  it "should initialize the client's job_id if passed as a client_option" do
    client = mock 'client'
    job_id = '289'
    AgentTestClient.expects(:new).with(anything, job_id).returns client

    client.expects(:run)

    @agent.stubs(:disabled?).returns false
    @agent.run(:job_id => job_id)
  end

  it "should be considered running if the lock file is locked" do
    lockfile = mock 'lockfile'

    @agent.expects(:lockfile).returns(lockfile)
    lockfile.expects(:locked?).returns true

    expect(@agent).to be_running
  end

  describe "when being run" do
    before do
      AgentTestClient.stubs(:lockfile_path).returns "/my/lock"
      @agent.stubs(:disabled?).returns false
    end

    it "should splay" do
      @agent.expects(:splay)

      @agent.run
    end

    it "should do nothing if disabled" do
      @agent.expects(:disabled?).returns(true)
      AgentTestClient.expects(:new).never
      @agent.run
    end

    it "(#11057) should notify the user about why a run is skipped" do
      Puppet::Application.stubs(:controlled_run).returns(false)
      Puppet::Application.stubs(:run_status).returns('MOCK_RUN_STATUS')
      # This is the actual test that we inform the user why the run is skipped.
      # We assume this information is contained in
      # Puppet::Application.run_status
      Puppet.expects(:notice).with(regexp_matches(/MOCK_RUN_STATUS/))
      @agent.run
    end

    it "should display an informative message if the agent is administratively disabled" do
      @agent.expects(:disabled?).returns true
      @agent.expects(:disable_message).returns "foo"
      Puppet.expects(:notice).with(regexp_matches(/Skipping run of .*; administratively disabled.*\(Reason: 'foo'\)/))
      @agent.run
    end

    it "should use Puppet::Application.controlled_run to manage process state behavior" do
      calls = sequence('calls')
      Puppet::Application.expects(:controlled_run).yields.in_sequence(calls)
      AgentTestClient.expects(:new).once.in_sequence(calls)
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

      client.expects(:run).with { expect(@agent.client).to equal(client); true }
      @agent.run
    end

    it "should run the client instance with any arguments passed to it" do
      client = AgentTestClient.new
      AgentTestClient.expects(:new).returns client

      client.expects(:run).with(:pluginsync => true, :other => :options)
      @agent.run(:other => :options)
    end

    it "should return the agent result" do
      client = AgentTestClient.new
      AgentTestClient.expects(:new).returns client

      @agent.expects(:lock).returns(:result)
      expect(@agent.run).to eq(:result)
    end

    describe "when should_fork is true", :if => Puppet.features.posix? do
      before do
        @agent = Puppet::Agent.new(AgentTestClient, true)

        # So we don't actually try to hit the filesystem.
        @agent.stubs(:lock).yields

        Kernel.stubs(:fork)
        Process.stubs(:waitpid2).returns [123, (stub 'process::status', :exitstatus => 0)]
        @agent.stubs(:exit)
      end

      it "should run the agent in a forked process" do
        client = AgentTestClient.new
        AgentTestClient.expects(:new).returns client

        client.expects(:run)

        Kernel.expects(:fork).yields
        @agent.run
      end

      it "should exit child process if child exit" do
        client = AgentTestClient.new
        AgentTestClient.expects(:new).returns client

        client.expects(:run).raises(SystemExit)

        Kernel.expects(:fork).yields
        @agent.expects(:exit).with(-1)
        @agent.run
      end

      it 'should exit with 1 if an exception is raised' do
        client = AgentTestClient.new
        AgentTestClient.expects(:new).returns client

        client.expects(:run).raises(StandardError)

        Kernel.expects(:fork).yields
        @agent.expects(:exit).with(1)
        @agent.run
      end

      it "should re-raise exit happening in the child" do
        Process.stubs(:waitpid2).returns [123, (stub 'process::status', :exitstatus => -1)]
        expect { @agent.run }.to raise_error(SystemExit)
      end

      it "should re-raise NoMoreMemory happening in the child" do
        Process.stubs(:waitpid2).returns [123, (stub 'process::status', :exitstatus => -2)]
        expect { @agent.run }.to raise_error(NoMemoryError)
      end

      it "should return the child exit code" do
        Process.stubs(:waitpid2).returns [123, (stub 'process::status', :exitstatus => 777)]
        expect(@agent.run).to eq(777)
      end

      it "should return the block exit code as the child exit code" do
        Kernel.expects(:fork).yields
        @agent.expects(:exit).with(777)
        @agent.run_in_fork {
          777
        }
      end
    end

    describe "on Windows", :if => Puppet.features.microsoft_windows? do
      it "should never fork" do
        agent = Puppet::Agent.new(AgentTestClient, true)
        expect(agent.should_fork).to be_falsey
      end
    end

    describe 'when runtimeout is set' do
      before(:each) do
        Puppet[:runtimeout] = 1
      end

      it 'times out when a run exceeds the set limit' do
        client = AgentTestClient.new
        client.instance_eval do
          # Stub methods used to set test expectations.
          def processing; end
          def handling; end

          def run(client_options = {})
            # Simulate a hanging agent operation that also traps errors.
            begin
              ::Kernel.sleep(5)
              processing()
            rescue
              handling()
            end
          end
        end

        AgentTestClient.expects(:new).returns client

        client.expects(:processing).never
        client.expects(:handling).never
        Puppet.expects(:log_exception).with(instance_of(Puppet::Agent::RunTimeoutError), anything)

        expect(@agent.run).to eq(1)
      end
    end
  end

  describe "when checking execution state" do
    describe 'with regular run status' do
      before :each do
        Puppet::Application.stubs(:restart_requested?).returns(false)
        Puppet::Application.stubs(:stop_requested?).returns(false)
        Puppet::Application.stubs(:interrupted?).returns(false)
        Puppet::Application.stubs(:clear?).returns(true)
      end

      it 'should be false for :stopping?' do
        expect(@agent.stopping?).to be_falsey
      end

      it 'should be false for :needing_restart?' do
        expect(@agent.needing_restart?).to be_falsey
      end
    end

    describe 'with a stop requested' do
      before :each do
        Puppet::Application.stubs(:clear?).returns(false)
        Puppet::Application.stubs(:restart_requested?).returns(false)
        Puppet::Application.stubs(:stop_requested?).returns(true)
        Puppet::Application.stubs(:interrupted?).returns(true)
      end

      it 'should be true for :stopping?' do
        expect(@agent.stopping?).to be_truthy
      end

      it 'should be false for :needing_restart?' do
        expect(@agent.needing_restart?).to be_falsey
      end
    end

    describe 'with a restart requested' do
      before :each do
        Puppet::Application.stubs(:clear?).returns(false)
        Puppet::Application.stubs(:restart_requested?).returns(true)
        Puppet::Application.stubs(:stop_requested?).returns(false)
        Puppet::Application.stubs(:interrupted?).returns(true)
      end

      it 'should be false for :stopping?' do
        expect(@agent.stopping?).to be_falsey
      end

      it 'should be true for :needing_restart?' do
        expect(@agent.needing_restart?).to be_truthy
      end
    end
  end
end
