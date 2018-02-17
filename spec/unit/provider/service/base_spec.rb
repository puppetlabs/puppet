#! /usr/bin/env ruby
require 'spec_helper'
require 'rbconfig'
require 'fileutils'

describe "base service provider" do
  include PuppetSpec::Files

  let :type do Puppet::Type.type(:service) end
  let :provider do type.provider(:base) end
  let(:executor) { Puppet::Util::Execution }
  let(:start_command) { 'start' }
  let(:status_command) { 'status' }
  let(:stop_command) { 'stop' }

  subject { provider }

  if Puppet.features.microsoft_windows?
    # Get a pid for $CHILD_STATUS to latch on to
    cmd = "cmd.exe /c \"exit 0\""
    Puppet::Util::Execution.execute(cmd, {:failonfail => false})
  end

  context "basic operations" do
    subject do
      type.new(
         :name  => "test",
         :provider => :base,
         :start  => start_command,
         :status => status_command,
         :stop   => stop_command
      ).provider
    end

    def execute_command(command, options)
      case command.shift
      when start_command
        expect(options[:failonfail]).to eq(true)
        raise(Puppet::ExecutionFailure, 'failed to start') if @running
        @running = true
        return 'started'
      when status_command
        expect(options[:failonfail]).to eq(false)
        $CHILD_STATUS.expects(:exitstatus).at_least(1).returns(@running ? 0 : 1)
        return @running ? 'running' : 'not running'
      when stop_command
        expect(options[:failonfail]).to eq(true)
        raise(Puppet::ExecutionFailure, 'failed to stop') unless @running
        @running = false
        return 'stopped'
      else
        raise "unexpected command execution: #{command}"
      end
    end

    before :each do
      @running = false
      executor.expects(:execute).at_least(1).with { |command, options| execute_command(command, options) }
    end

    it "should invoke the start command if not running" do
      subject.start
    end

    it "should be stopped before being started" do
      expect(subject.status).to eq(:stopped)
    end

    it "should be running after being started" do
      subject.start
      expect(subject.status).to eq(:running)
    end

    it "should invoke the stop command when asked" do
      subject.start
      expect(subject.status).to eq(:running)
      subject.stop
      expect(subject.status).to eq(:stopped)
    end

    it "should raise an error if started twice" do
      subject.start
      expect {subject.start }.to raise_error(Puppet::Error, 'Could not start Service[test]: failed to start')
    end

    it "should raise an error if stopped twice" do
      subject.start
      subject.stop
      expect {subject.stop }.to raise_error(Puppet::Error, 'Could not stop Service[test]: failed to stop')
    end
  end

  context "when hasstatus is false" do
    subject do
      type.new(
         :name  => "status test",
         :provider => :base,
         :hasstatus => false,
         :pattern => "majestik m\u00f8\u00f8se",
      ).provider
    end

    it "retrieves a PID from the process table" do
      Facter.stubs(:value).with(:operatingsystem).returns("CentOS")
      ps_output = File.binread(my_fixture("ps_ef.mixed_encoding")).force_encoding(Encoding::UTF_8)

      executor.expects(:execute).with("ps -ef").returns(ps_output)

      expect(subject.status).to eq(:running)
    end
  end
end
