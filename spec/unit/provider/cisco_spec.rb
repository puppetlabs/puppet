require 'spec_helper'

require 'puppet/provider/cisco'

describe Puppet::Provider::Cisco do
  it "should implement a device class method" do
    expect(Puppet::Provider::Cisco).to respond_to(:device)
  end

  it "should create a cisco device instance" do
    expect(Puppet::Util::NetworkDevice::Cisco::Device).to receive(:new).and_return(:device)
    expect(Puppet::Provider::Cisco.device(:url)).to eq(:device)
  end
end
