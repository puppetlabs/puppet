#! /usr/bin/env ruby
#
# Unit testing for the Windows service Provider
#

require 'spec_helper'

require 'win32/service' if Puppet.features.microsoft_windows?

describe Puppet::Type.type(:service).provider(:windows), :if => Puppet.features.microsoft_windows? do
  let(:name)     { 'nonexistentservice' }
  let(:resource) { Puppet::Type.type(:service).new(:name => name, :provider => :windows) }
  let(:provider) { resource.provider }
  let(:config)   { Struct::ServiceConfigInfo.new }
  let(:status)   { Struct::ServiceStatus.new }
  let(:service_util) { Puppet::Util::Windows::Service }
  let(:service_handle) { mock() }

  before :each do
    # make sure we never actually execute anything (there are two execute methods)
    provider.class.expects(:execute).never
    provider.expects(:execute).never

    service_util.stubs(:exists?).with(resource[:name]).returns(true)
  end

  describe ".instances" do
    it "should enumerate all services" do
      list_of_services = {'snmptrap' => {}, 'svchost' => {}, 'sshd' => {}}
      service_util.expects(:services).returns(list_of_services)

      expect(described_class.instances.map(&:name)).to match_array(['snmptrap', 'svchost', 'sshd'])
    end
  end

  describe "#start" do
    before(:each) do
      provider.stubs(:status).returns(:stopped)
    end

    it "should resume a paused service" do
      provider.stubs(:status).returns(:paused)
      service_util.expects(:resume).with(name)
      provider.start
    end

    it "should start the service" do
      service_util.expects(:service_start_type).with(name).returns(:SERVICE_AUTO_START)
      service_util.expects(:start).with(name)
      provider.start
    end

    context "when the service is disabled" do
      before :each do
        service_util.expects(:service_start_type).with(name).returns(:SERVICE_DISABLED)
      end

      it "should refuse to start if not managing enable" do
        expect { provider.start }.to raise_error(Puppet::Error, /Will not start disabled service/)
      end

      it "should enable if managing enable and enable is true" do
        resource[:enable] = :true
        service_util.expects(:start).with(name)
        service_util.expects(:set_startup_mode).with(name, :SERVICE_AUTO_START)

        provider.start
      end

      it "should manual start if managing enable and enable is false" do
        resource[:enable] = :false
        service_util.expects(:start).with(name)
        service_util.expects(:set_startup_mode).with(name, :SERVICE_DEMAND_START)

        provider.start
      end
    end
  end

  describe "#stop" do
    it "should stop a running service" do
      service_util.expects(:stop).with(name)

      provider.stop
    end
  end

  describe "#status" do
    it "should report a nonexistent service as stopped" do
      service_util.stubs(:exists?).with(resource[:name]).returns(false)

      expect(provider.status).to eql(:stopped)
    end

    [
      :SERVICE_PAUSED,
      :SERVICE_PAUSE_PENDING
    ].each do |state|
      it "should report a #{state} service as paused" do
        service_util.expects(:service_state).with(name).returns(state)
        expect(provider.status).to eq(:paused)
      end
    end

    [
      :SERVICE_STOPPED,
      :SERVICE_STOP_PENDING
    ].each do |state|
      it "should report a #{state} service as stopped" do
        service_util.expects(:service_state).with(name).returns(state)
        expect(provider.status).to eq(:stopped)
      end
    end

    [
      :SERVICE_RUNNING,
      :SERVICE_CONTINUE_PENDING,
      :SERVICE_START_PENDING,
    ].each do |state|
      it "should report a #{state} service as running" do
        service_util.expects(:service_state).with(name).returns(state)

        expect(provider.status).to eq(:running)
      end
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      resource[:restart] = 'c:/bin/foo'

      provider.expects(:execute).never
      provider.expects(:execute).with(['c:/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)

      provider.restart
    end

    it "should restart the service" do
      seq = sequence("restarting")
      provider.expects(:stop).in_sequence(seq)
      provider.expects(:start).in_sequence(seq)

      provider.restart
    end
  end

  describe "#enabled?" do
    it "should report a nonexistent service as false" do
      service_util.stubs(:exists?).with(resource[:name]).returns(false)

      expect(provider.enabled?).to eql(:false)
    end

    it "should report a service with a startup type of manual as manual" do
      service_util.expects(:service_start_type).with(name).returns(:SERVICE_DEMAND_START)
      expect(provider.enabled?).to eq(:manual)
    end

    it "should report a service with a startup type of disabled as false" do
      service_util.expects(:service_start_type).with(name).returns(:SERVICE_DISABLED)
      expect(provider.enabled?).to eq(:false)
    end

    # We need to guard this section explicitly since rspec will always
    # construct all examples, even if it isn't going to run them.
    if Puppet.features.microsoft_windows?
      [
        :SERVICE_AUTO_START,
        :SERVICE_BOOT_START,
        :SERVICE_SYSTEM_START
      ].each do |start_type|
        it "should report a service with a startup type of '#{start_type}' as true" do
          service_util.expects(:service_start_type).with(name).returns(start_type)
          expect(provider.enabled?).to eq(:true)
        end
      end
    end
  end

  describe "#enable" do
    it "should set service start type to Service_Auto_Start when enabled" do
      service_util.expects(:set_startup_mode).with(name, :SERVICE_AUTO_START)
      provider.enable
    end

    it "raises an error if set_startup_mode fails" do
      service_util.expects(:set_startup_mode).with(name, :SERVICE_AUTO_START).raises(Puppet::Error.new('foobar'))

      expect {
        provider.enable
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end

  describe "#disable" do
    it "should set service start type to Service_Disabled when disabled" do
      service_util.expects(:set_startup_mode).with(name, :SERVICE_DISABLED)
      provider.disable
    end

    it "raises an error if set_startup_mode fails" do
      service_util.expects(:set_startup_mode).with(name, :SERVICE_DISABLED).raises(Puppet::Error.new('foobar'))

      expect {
        provider.disable
      }.to raise_error(Puppet::Error, /Cannot disable #{name}/)
    end
  end

  describe "#manual_start" do
    it "should set service start type to Service_Demand_Start (manual) when manual" do
      service_util.expects(:set_startup_mode).with(name, :SERVICE_DEMAND_START)
      provider.manual_start
    end

    it "raises an error if set_startup_mode fails" do
      service_util.expects(:set_startup_mode).with(name, :SERVICE_DEMAND_START).raises(Puppet::Error.new('foobar'))

      expect {
        provider.manual_start
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end
end
