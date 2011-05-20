#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/provider/cisco'

describe Puppet::Provider::Cisco do
  it "should implement a device class method" do
    Puppet::Provider::Cisco.should respond_to(:device)
  end

  it "should create a cisco device instance" do
    Puppet::Util::NetworkDevice::Cisco::Device.expects(:new).returns :device
    Puppet::Provider::Cisco.device(:url).should == :device
  end
end
