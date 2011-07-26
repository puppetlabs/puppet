#!/usr/bin/env rspec
#
# Unit testing for the Windows service Provider
#

require 'spec_helper'

require 'ostruct'
require 'win32/service' if Puppet.features.microsoft_windows?

provider_class = Puppet::Type.type(:service).provider(:windows)

describe provider_class, :if => Puppet.features.microsoft_windows? do

  before :each do
    @provider = Puppet::Type.type(:service).provider(:windows)
    Puppet::Type.type(:service).stubs(:provider).returns(@provider)
  end

  describe ".instances" do
    it "should enumerate all services" do
      list_of_services = ['snmptrap', 'svchost', 'sshd'].map {|s| OpenStruct.new(:service_name => s)}
      Win32::Service.expects(:services).returns(list_of_services)

      provider_class.instances.map {|provider| provider.name}.should =~ ['snmptrap', 'svchost', 'sshd']
    end
  end

  describe "#start" do
    it "should call out to the Win32::Service API to start the service" do
      Win32::Service.expects(:start).with('snmptrap')

      resource = Puppet::Type.type(:service).new(:name => 'snmptrap')
      resource.provider.start
    end

    it "should handle when Win32::Service.start raises a Win32::Service::Error" do
      Win32::Service.expects(:start).with('snmptrap').raises(
        Win32::Service::Error.new("The service cannot be started, either because it is disabled or because it has no enabled devices associated with it.")
      )

      resource = Puppet::Type.type(:service).new(:name => 'snmptrap')
      expect { resource.provider.start }.to raise_error(
        Puppet::Error,
        /Cannot start snmptrap, error was: The service cannot be started, either/
      )
    end
  end

  describe "#stop" do
    it "should stop a running service"
    it "should not try to stop an already stopped service"
  end

  describe "#status" do
    ['stopped', 'paused', 'stop pending', 'pause pending'].each do |state|
      it "should report a #{state} service as stopped" do
        Win32::Service.expects(:status).with('snmptrap').returns(
          stub(
            'struct_service_status',
            :instance_of?  => Struct::ServiceStatus,
            :current_state => state
          )
        )
        resource = Puppet::Type.type(:service).new(:name => 'snmptrap')

        resource.provider.status.should == :stopped
      end
    end

    ["running", "continue pending", "start pending" ].each do |state|
      it "should report a #{state} service as running" do
        Win32::Service.expects(:status).with('snmptrap').returns(
          stub(
            'struct_service_status',
            :instance_of?  => Struct::ServiceStatus,
            :current_state => state
          )
        )
        resource = Puppet::Type.type(:service).new(:name => 'snmptrap')
        resource.provider.status.should == :running
      end
    end
  end

  describe "#enabled?" do
    it "should report a service with a startup type of manual as manual" do
      Win32::Service.expects(:config_info).with('snmptrap').returns(
        stub(
          'struct_config_info',
          :instance_of? => Struct::ServiceConfigInfo,
          :start_type   => Win32::Service.get_start_type(Win32::Service::SERVICE_DEMAND_START)
        )
      )
      resource = Puppet::Type.type(:service).new(:name => 'snmptrap')
      resource.provider.enabled?.should == :manual
    end

    it "should report a service with a startup type of disabled as false" do
      Win32::Service.expects(:config_info).with('snmptrap').returns(
        stub(
          'struct_config_info',
          :instance_of? => Struct::ServiceConfigInfo,
          :start_type   => Win32::Service.get_start_type(Win32::Service::SERVICE_DISABLED)
        )
      )
      resource = Puppet::Type.type(:service).new(:name => 'snmptrap')
      resource.provider.enabled?.should == :false
    end

    # We need to guard this section explicitly since rspec will always
    # construct all examples, even if it isn't going to run them.
    if Puppet.features.microsoft_windows?
      [Win32::Service::SERVICE_AUTO_START, Win32::Service::SERVICE_BOOT_START, Win32::Service::SERVICE_SYSTEM_START].each do |start_type_const|
        start_type = Win32::Service.get_start_type(start_type_const)
        it "should report a service with a startup type of '#{start_type}' as true" do
          Win32::Service.expects(:config_info).with('snmptrap').returns(
            stub(
              'struct_config_info',
              :instance_of? => Struct::ServiceConfigInfo,
              :start_type   => start_type
            )
          )
          resource = Puppet::Type.type(:service).new(:name => 'snmptrap')
          resource.provider.enabled?.should == :true
        end
      end
    end
  end
end
