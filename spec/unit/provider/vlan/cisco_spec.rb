require 'spec_helper'

require 'puppet/provider/vlan/cisco'

provider_class = Puppet::Type.type(:vlan).provider(:cisco)

describe provider_class do
  before do
    @device = double('device')
    @resource = double("resource", :name => "200")
    @provider = provider_class.new(@device, @resource)
  end

  it "should have a parent of Puppet::Provider::Cisco" do
    expect(provider_class).to be < Puppet::Provider::Cisco
  end

  it "should have an instances method" do
    expect(provider_class).to respond_to(:instances)
  end

  describe "when looking up instances at prefetch" do
    before do
      allow(@device).to receive(:command).and_yield(@device)
    end

    it "should delegate to the device vlans" do
      expect(@device).to receive(:parse_vlans)
      provider_class.lookup(@device, "200")
    end

    it "should return only the given vlan" do
      expect(@device).to receive(:parse_vlans).and_return({"200" => { :description => "thisone" }, "1" => { :description => "nothisone" }})
      expect(provider_class.lookup(@device, "200")).to eq({:description => "thisone" })
    end
  end

  describe "when an instance is being flushed" do
    it "should call the device update_vlan method with its vlan id, current attributes, and desired attributes" do
      @instance = provider_class.new(@device, :ensure => :present, :name => "200", :description => "myvlan")
      @instance.description = "myvlan2"
      @instance.resource = @resource
      allow(@resource).to receive(:[]).with(:name).and_return("200")
      device = double('device')
      allow(@instance).to receive(:device).and_return(device)
      expect(device).to receive(:command).and_yield(device)
      expect(device).to receive(:update_vlan).with(@instance.name, {:ensure => :present, :name => "200", :description => "myvlan"},
                                                   {:ensure => :present, :name => "200", :description => "myvlan2"})

      @instance.flush
    end
  end
end
