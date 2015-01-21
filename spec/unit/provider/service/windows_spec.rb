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

  before :each do
    # make sure we never actually execute anything (there are two execute methods)
    provider.class.expects(:execute).never
    provider.expects(:execute).never

    Win32::Service.stubs(:config_info).with(name).returns(config)
    Win32::Service.stubs(:status).with(name).returns(status)
  end

  describe ".instances" do
    it "should enumerate all services" do
      list_of_services = ['snmptrap', 'svchost', 'sshd'].map { |s| stub('service', :service_name => s) }
      Win32::Service.expects(:services).returns(list_of_services)

      expect(described_class.instances.map(&:name)).to match_array(['snmptrap', 'svchost', 'sshd'])
    end
  end

  describe "#start" do
    before :each do
      config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_AUTO_START)
    end

    it "should start the service" do
      provider.expects(:net).with(:start, name)

      provider.start
    end

    it "should raise an error if the start command fails" do
      provider.expects(:net).with(:start, name).raises(Puppet::ExecutionFailure, "The service name is invalid.")

      expect {
        provider.start
      }.to raise_error(Puppet::Error, /Cannot start #{name}, error was: The service name is invalid./)
    end

    it "raises an error if the service doesn't exist" do
      Win32::Service.expects(:config_info).with(name).raises(SystemCallError, 'OpenService')

      expect {
        provider.start
      }.to raise_error(Puppet::Error, /Cannot get start type for #{name}/)
    end

    describe "when the service is disabled" do
      before :each do
        config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_DISABLED)
      end

      it "should refuse to start if not managing enable" do
        expect { provider.start }.to raise_error(Puppet::Error, /Will not start disabled service/)
      end

      it "should enable if managing enable and enable is true" do
        resource[:enable] = :true

        provider.expects(:net).with(:start, name)
        Win32::Service.expects(:configure).with('service_name' => name, 'start_type' => Win32::Service::SERVICE_AUTO_START).returns(Win32::Service)

        provider.start
      end

      it "should manual start if managing enable and enable is false" do
        resource[:enable] = :false

        provider.expects(:net).with(:start, name)
        Win32::Service.expects(:configure).with('service_name' => name, 'start_type' => Win32::Service::SERVICE_DEMAND_START).returns(Win32::Service)

        provider.start
      end
    end
  end

  describe "#stop" do
    it "should stop a running service" do
      provider.expects(:net).with(:stop, name)

      provider.stop
    end

    it "should raise an error if the stop command fails" do
      provider.expects(:net).with(:stop, name).raises(Puppet::ExecutionFailure, 'The service name is invalid.')

      expect {
        provider.stop
      }.to raise_error(Puppet::Error, /Cannot stop #{name}, error was: The service name is invalid./)
    end
  end

  describe "#status" do
    ['stopped', 'paused', 'stop pending', 'pause pending'].each do |state|
      it "should report a #{state} service as stopped" do
        status.current_state = state

        expect(provider.status).to eq(:stopped)
      end
    end

    ["running", "continue pending", "start pending" ].each do |state|
      it "should report a #{state} service as running" do
        status.current_state = state

        expect(provider.status).to eq(:running)
      end
    end

    it "raises an error if the service doesn't exist" do
      Win32::Service.expects(:status).with(name).raises(SystemCallError, 'OpenService')

      expect {
        provider.status
      }.to raise_error(Puppet::Error, /Cannot get status of #{name}/)
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
    it "should report a service with a startup type of manual as manual" do
      config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_DEMAND_START)

      expect(provider.enabled?).to eq(:manual)
    end

    it "should report a service with a startup type of disabled as false" do
      config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_DISABLED)

      expect(provider.enabled?).to eq(:false)
    end

    it "raises an error if the service doesn't exist" do
      Win32::Service.expects(:config_info).with(name).raises(SystemCallError, 'OpenService')

      expect {
        provider.enabled?
      }.to raise_error(Puppet::Error, /Cannot get start type for #{name}/)
    end

    # We need to guard this section explicitly since rspec will always
    # construct all examples, even if it isn't going to run them.
    if Puppet.features.microsoft_windows?
      [Win32::Service::SERVICE_AUTO_START, Win32::Service::SERVICE_BOOT_START, Win32::Service::SERVICE_SYSTEM_START].each do |start_type_const|
        start_type = Win32::Service.get_start_type(start_type_const)
        it "should report a service with a startup type of '#{start_type}' as true" do
          config.start_type = start_type

          expect(provider.enabled?).to eq(:true)
        end
      end
    end
  end

  describe "#enable" do
    it "should set service start type to Service_Auto_Start when enabled" do
      Win32::Service.expects(:configure).with('service_name' => name, 'start_type' => Win32::Service::SERVICE_AUTO_START).returns(Win32::Service)
      provider.enable
    end

    it "raises an error if the service doesn't exist" do
      Win32::Service.expects(:configure).with(has_entry('service_name' => name)).raises(SystemCallError, 'OpenService')

      expect {
        provider.enable
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end

  describe "#disable" do
    it "should set service start type to Service_Disabled when disabled" do
      Win32::Service.expects(:configure).with('service_name' => name, 'start_type' => Win32::Service::SERVICE_DISABLED).returns(Win32::Service)
      provider.disable
     end

    it "raises an error if the service doesn't exist" do
      Win32::Service.expects(:configure).with(has_entry('service_name' => name)).raises(SystemCallError, 'OpenService')

      expect {
        provider.disable
      }.to raise_error(Puppet::Error, /Cannot disable #{name}/)
    end
  end

  describe "#manual_start" do
    it "should set service start type to Service_Demand_Start (manual) when manual" do
      Win32::Service.expects(:configure).with('service_name' => name, 'start_type' => Win32::Service::SERVICE_DEMAND_START).returns(Win32::Service)
      provider.manual_start
    end

    it "raises an error if the service doesn't exist" do
      Win32::Service.expects(:configure).with(has_entry('service_name' => name)).raises(SystemCallError, 'OpenService')

      expect {
        provider.manual_start
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end
end
