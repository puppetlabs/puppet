#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:upstart)

describe provider_class do
  describe "#instances" do
    it "should be able to find all instances" do
      processes = ["rc stop/waiting", "ssh start/running, process 712"]
      provider_class.stubs(:execpipe).yields(processes)
      provider_class.instances.map {|provider| provider.name}.should =~ ["rc","ssh"]
    end

    it "should attach the interface name for network interfaces" do
      processes = ["network-interface (eth0)"]
      provider_class.stubs(:execpipe).yields(processes)
      provider_class.instances.first.name.should == "network-interface INTERFACE=eth0"
    end
  end

  describe "#status" do
    it "should allow the user to override the status command" do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart, :status => "/bin/foo")
      provider = provider_class.new(resource)

      provider.expects(:ucommand).with { `true`; true }
      provider.status.should == :running
    end

    it "should use the default status command if none is specified" do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
      provider = provider_class.new(resource)

      provider.expects(:status_exec).with(["foo"]).returns("foo start/running, process 1000")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      provider.status.should == :running
    end

    it "should properly handle services with 'start' in their name" do
      resource = Puppet::Type.type(:service).new(:name => "foostartbar", :provider => :upstart)
      provider = provider_class.new(resource)

      provider.expects(:status_exec).with(["foostartbar"]).returns("foostartbar stop/waiting")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      provider.status.should == :stopped
    end
  end
end
