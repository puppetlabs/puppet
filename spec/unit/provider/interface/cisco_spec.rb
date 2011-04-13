#!/usr/bin/env rspec

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/provider/interface/cisco'

provider_class = Puppet::Type.type(:interface).provider(:cisco)

describe provider_class do
  before do
    @resource = stub("resource", :name => "Fa0/1")
    @provider = provider_class.new(@resource)
  end

  it "should have a parent of Puppet::Provider::NetworkDevice" do
    provider_class.should < Puppet::Provider::NetworkDevice
  end

  it "should have an instances method" do
    provider_class.should respond_to(:instances)
  end

  describe "when looking up instances at prefetch" do
    before do
      @device = stub_everything 'device'
      Puppet::Util::NetworkDevice::Cisco::Device.stubs(:new).returns(@device)
      @device.stubs(:command).yields(@device)
    end

    it "should initialize the network device with the given url" do
      Puppet::Util::NetworkDevice::Cisco::Device.expects(:new).with(:url).returns(@device)
      provider_class.lookup(:url, "Fa0/1")
    end

    it "should delegate to the device interface fetcher" do
      @device.expects(:interface)
      provider_class.lookup("", "Fa0/1")
    end

    it "should return the given interface data" do
      @device.expects(:interface).returns({ :description => "thisone", :mode => :access})
      provider_class.lookup("", "Fa0").should == {:description => "thisone", :mode => :access }
    end

  end

  describe "when an instance is being flushed" do
    it "should call the device interface update method with current and past properties" do
      @instance = provider_class.new(:ensure => :present, :name => "Fa0/1", :description => "myinterface")
      @instance.description = "newdesc"
      @instance.resource = @resource
      @resource.stubs(:[]).with(:name).returns("Fa0/1")
      device = stub_everything 'device'
      @instance.stubs(:device).returns(device)
      device.expects(:command).yields(device)
      interface = stub 'interface'
      device.expects(:new_interface).with("Fa0/1").returns(interface)
      interface.expects(:update).with( {:ensure => :present, :name => "Fa0/1", :description => "myinterface"},
                                       {:ensure => :present, :name => "Fa0/1", :description => "newdesc"})

      @instance.flush
    end
  end
end
