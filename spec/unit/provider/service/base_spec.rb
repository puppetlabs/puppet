#! /usr/bin/env ruby
require 'spec_helper'
require 'rbconfig'
require 'fileutils'

provider_class = Puppet::Type.type(:service).provider(:init)

describe "base service provider" do
  include PuppetSpec::Files

  let :type do Puppet::Type.type(:service) end
  let :provider do type.provider(:base) end
  let(:executor) { Puppet::Util::Execution }
  let(:start_command) { 'start' }
  let(:status_command) { 'status' }
  let(:stop_command) { 'stop' }

  subject { provider }

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
end
