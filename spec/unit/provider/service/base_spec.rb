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

  before(:all) do
    `exit 0`
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
        Puppet::Util::Execution::ProcessOutput.new('started', 0)
      when status_command
        expect(options[:failonfail]).to eq(false)
        if @running
          Puppet::Util::Execution::ProcessOutput.new('running', 0)
        else
          Puppet::Util::Execution::ProcessOutput.new('not running', 1)
        end
      when stop_command
        expect(options[:failonfail]).to eq(true)
        raise(Puppet::ExecutionFailure, 'failed to stop') unless @running
        @running = false
        Puppet::Util::Execution::ProcessOutput.new('stopped', 0)
      else
        raise "unexpected command execution: #{command}"
      end
    end

    before :each do
      @running = false
      expect(executor).to receive(:execute).at_least(:once) { |command, options| execute_command(command, options) }
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
      allow(Facter).to receive(:value).with(:operatingsystem).and_return("CentOS")
      ps_output = File.binread(my_fixture("ps_ef.mixed_encoding")).force_encoding(Encoding::UTF_8)

      expect(executor).to receive(:execute).with("ps -ef").and_return(ps_output)

      expect(subject.status).to eq(:running)
    end
  end
end
