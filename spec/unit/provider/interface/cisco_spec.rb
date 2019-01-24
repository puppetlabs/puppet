require 'spec_helper'

require 'puppet/provider/interface/cisco'

describe Puppet::Type.type(:interface).provider(:cisco) do
  before do
    @device = double('device')
    @resource = double("resource", :name => "Fa0/1")
    @provider = described_class.new(@device, @resource)
  end

  it "should have a parent of Puppet::Provider::Cisco" do
    expect(described_class).to be < Puppet::Provider::Cisco
  end

  it "should have an instances method" do
    expect(described_class).to respond_to(:instances)
  end

  describe "when looking up instances at prefetch" do
    before do
      allow(@device).to receive(:command).and_yield(@device)
    end

    it "should delegate to the device interface fetcher" do
      expect(@device).to receive(:interface)
      described_class.lookup(@device, "Fa0/1")
    end

    it "should return the given interface data" do
      expect(@device).to receive(:interface).and_return({:description => "thisone", :mode => :access})
      expect(described_class.lookup(@device, "Fa0")).to eq({:description => "thisone", :mode => :access })
    end
  end

  describe "when an instance is being flushed" do
    it "should call the device interface update method with current and past properties" do
      @instance = described_class.new(@device, :ensure => :present, :name => "Fa0/1", :description => "myinterface")
      @instance.description = "newdesc"
      @instance.resource = @resource
      allow(@resource).to receive(:[]).with(:name).and_return("Fa0/1")
      device = double('device')
      allow(@instance).to receive(:device).and_return(device)
      expect(device).to receive(:command).and_yield(device)
      interface = double('interface')
      expect(device).to receive(:new_interface).with("Fa0/1").and_return(interface)
      expect(interface).to receive(:update).with( {:ensure => :present, :name => "Fa0/1", :description => "myinterface"},
                                                  {:ensure => :present, :name => "Fa0/1", :description => "newdesc"})

      @instance.flush
    end
  end
end
