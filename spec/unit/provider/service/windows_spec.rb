#!/usr/bin/env rspec
#
# Unit testing for the Windows service Provider
#

require 'spec_helper'

require 'win32/service' if Puppet.features.microsoft_windows?

describe Puppet::Type.type(:service).provider(:windows), :if => Puppet.features.microsoft_windows? do

  before :each do
    @resource = Puppet::Type.type(:service).new(:name => 'snmptrap', :provider => :windows)

    @config = Struct::ServiceConfigInfo.new

    @status = Struct::ServiceStatus.new

    Win32::Service.stubs(:config_info).with(@resource[:name]).returns(@config)
    Win32::Service.stubs(:status).with(@resource[:name]).returns(@status)
  end

  describe ".instances" do
    it "should enumerate all services" do
      list_of_services = ['snmptrap', 'svchost', 'sshd'].map { |s| stub('service', :service_name => s) }
      Win32::Service.expects(:services).returns(list_of_services)

      described_class.instances.map(&:name).should =~ ['snmptrap', 'svchost', 'sshd']
    end
  end

  describe "#start" do
    it "should call out to the Win32::Service API to start the service" do
      @config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_AUTO_START)

      Win32::Service.expects(:start).with( @resource[:name] )

      @resource.provider.start
    end

    it "should handle when Win32::Service.start raises a Win32::Service::Error" do
      @config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_AUTO_START)

      Win32::Service.expects(:start).with( @resource[:name] ).raises(
        Win32::Service::Error.new("The service cannot be started, either because it is disabled or because it has no enabled devices associated with it.")
      )

      expect { @resource.provider.start }.to raise_error(
        Puppet::Error,
        /Cannot start .*, error was: The service cannot be started, either/
      )
    end

    describe "when the service is disabled" do
      before :each do
        @config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_DISABLED)
        Win32::Service.stubs(:start).with(@resource[:name])
      end

      it "should refuse to start if not managing enable" do
        expect { @resource.provider.start }.to raise_error(Puppet::Error, /Will not start disabled service/)
      end

      it "should enable if managing enable and enable is true" do
        @resource[:enable] = :true

        Win32::Service.expects(:configure).with('service_name' => @resource[:name], 'start_type' => Win32::Service::SERVICE_AUTO_START).returns(Win32::Service)

        @resource.provider.start
      end

      it "should manual start if managing enable and enable is false" do
        @resource[:enable] = :false

        Win32::Service.expects(:configure).with('service_name' => @resource[:name], 'start_type' => Win32::Service::SERVICE_DEMAND_START).returns(Win32::Service)

        @resource.provider.start
      end
    end
  end

  describe "#stop" do
    it "should call out to the Win32::Service API to stop the service" do
      Win32::Service.expects(:stop).with( @resource[:name] )
      @resource.provider.stop
      end

    it "should handle when Win32::Service.stop raises a Win32::Service::Error" do
      Win32::Service.expects(:stop).with( @resource[:name] ).raises(
        Win32::Service::Error.new("should not try to stop an already stopped service.")
      )

      expect { @resource.provider.stop }.to raise_error(
        Puppet::Error,
        /Cannot stop .*, error was: should not try to stop an already stopped service/
      )
    end
  end

  describe "#status" do
    ['stopped', 'paused', 'stop pending', 'pause pending'].each do |state|
      it "should report a #{state} service as stopped" do
        @status.current_state = state

        @resource.provider.status.should == :stopped
      end
    end

    ["running", "continue pending", "start pending" ].each do |state|
      it "should report a #{state} service as running" do
        @status.current_state = state

        @resource.provider.status.should == :running
      end
    end
  end

  describe "#enabled?" do
    it "should report a service with a startup type of manual as manual" do
      @config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_DEMAND_START)

      @resource.provider.enabled?.should == :manual
    end

    it "should report a service with a startup type of disabled as false" do
      @config.start_type = Win32::Service.get_start_type(Win32::Service::SERVICE_DISABLED)

      @resource.provider.enabled?.should == :false
    end

    # We need to guard this section explicitly since rspec will always
    # construct all examples, even if it isn't going to run them.
    if Puppet.features.microsoft_windows?
      [Win32::Service::SERVICE_AUTO_START, Win32::Service::SERVICE_BOOT_START, Win32::Service::SERVICE_SYSTEM_START].each do |start_type_const|
        start_type = Win32::Service.get_start_type(start_type_const)
        it "should report a service with a startup type of '#{start_type}' as true" do
          @config.start_type = start_type

          @resource.provider.enabled?.should == :true
        end
      end
    end
  end

  describe "#enable" do
    it "should set service start type to Service_Auto_Start when enabled" do
      Win32::Service.expects(:configure).with('service_name' => @resource[:name], 'start_type' => Win32::Service::SERVICE_AUTO_START).returns(Win32::Service)
      @resource.provider.enable
    end
  end

  describe "#disable" do
    it "should set service start type to Service_Disabled when disabled" do
      Win32::Service.expects(:configure).with('service_name' => @resource[:name], 'start_type' => Win32::Service::SERVICE_DISABLED).returns(Win32::Service)
      @resource.provider.disable
     end
  end

  describe "#manual_start" do
    it "should set service start type to Service_Demand_Start (manual) when manual" do
      Win32::Service.expects(:configure).with('service_name' => @resource[:name], 'start_type' => Win32::Service::SERVICE_DEMAND_START).returns(Win32::Service)
      @resource.provider.manual_start
    end
  end

end
