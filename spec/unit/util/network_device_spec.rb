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
    it "should create a network device instance" do
      allow(Puppet::Util::NetworkDevice).to receive(:require)
      expect(Puppet::Util::NetworkDevice::Test::Device).to receive(:new).with("telnet://admin:password@127.0.0.1", {:debug => false})
      Puppet::Util::NetworkDevice.init(@device)
    end

    it "should raise an error if the remote device instance can't be created" do
      allow(Puppet::Util::NetworkDevice).to receive(:require).and_raise("error")
      expect { Puppet::Util::NetworkDevice.init(@device) }.to raise_error(RuntimeError, /Can't load test for name/)
    end

    it "should let caller to access the singleton device" do
      device = double('device')
      allow(Puppet::Util::NetworkDevice).to receive(:require)
      expect(Puppet::Util::NetworkDevice::Test::Device).to receive(:new).and_return(device)
      Puppet::Util::NetworkDevice.init(@device)

      expect(Puppet::Util::NetworkDevice.current).to eq(device)
    end
  end
end
