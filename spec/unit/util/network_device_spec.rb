#! /usr/bin/env ruby
require 'spec_helper'

require 'ostruct'
require 'puppet/util/network_device'

describe Puppet::Util::NetworkDevice do

  before(:each) do
    @device = OpenStruct.new(:name => "name", :provider => "test", :url => "telnet://admin:password@127.0.0.1", :options => { :debug => false })
  end

  after(:each) do
    Puppet::Util::NetworkDevice.teardown
  end

  class Puppet::Util::NetworkDevice::Test
    class Device
      def initialize(device, options)
      end
    end
  end

  describe "when initializing the remote network device singleton" do
    it "should load the network device code" do
      Puppet::Util::NetworkDevice.expects(:require)
      Puppet::Util::NetworkDevice.init(@device)
    end

    it "should create a network device instance" do
      Puppet::Util::NetworkDevice.stubs(:require)
      Puppet::Util::NetworkDevice::Test::Device.expects(:new).with("telnet://admin:password@127.0.0.1", :debug => false)
      Puppet::Util::NetworkDevice.init(@device)
    end

    it "should raise an error if the remote device instance can't be created" do
      Puppet::Util::NetworkDevice.stubs(:require).raises("error")
      expect { Puppet::Util::NetworkDevice.init(@device) }.to raise_error(RuntimeError, /Can't load test for name/)
    end

    it "should let caller to access the singleton device" do
      device = stub 'device'
      Puppet::Util::NetworkDevice.stubs(:require)
      Puppet::Util::NetworkDevice::Test::Device.expects(:new).returns(device)
      Puppet::Util::NetworkDevice.init(@device)

      expect(Puppet::Util::NetworkDevice.current).to eq(device)
    end
  end
end
