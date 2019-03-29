require 'spec_helper'

require 'puppet/provider/network_device'
require 'ostruct'

Puppet::Type.type(:vlan).provide :test, :parent => Puppet::Provider::NetworkDevice do
  mk_resource_methods
  def self.lookup(device, name)
  end

  def self.device(url)
    :device
  end
end

provider_class = Puppet::Type.type(:vlan).provider(:test)

describe provider_class do
  before do
    @resource = double("resource", :name => "test")
    @provider = provider_class.new(@resource)
  end

  it "should be able to prefetch instances from the device" do
    expect(provider_class).to respond_to(:prefetch)
  end

  it "should have an instances method" do
    expect(provider_class).to respond_to(:instances)
  end

  describe "when prefetching" do
    before do
      @resource = double('resource')
      allow(@resource).to receive(:[])
      @resources = {"200" => @resource}
      allow(provider_class).to receive(:lookup)
    end

    it "should lookup an entry for each passed resource" do
      expect(provider_class).to receive(:lookup).with(anything, "200").and_return(nil)

      allow(provider_class).to receive(:new)
      allow(@resource).to receive(:provider=)
      provider_class.prefetch(@resources)
    end

    describe "resources that do not exist" do
      it "should create a provider with :ensure => :absent" do
        allow(provider_class).to receive(:lookup).and_return(nil)
        expect(provider_class).to receive(:new).with(:device, :ensure => :absent).and_return("myprovider")
        expect(@resource).to receive(:provider=).with("myprovider")
        provider_class.prefetch(@resources)
      end
    end

    describe "resources that exist" do
      it "should create a provider with the results of the find and ensure at present" do
        allow(provider_class).to receive(:lookup).and_return({ :name => "200", :description => "myvlan"})

        expect(provider_class).to receive(:new).with(:device, :name => "200", :description => "myvlan", :ensure => :present).and_return("myprovider")
        expect(@resource).to receive(:provider=).with("myprovider")

        provider_class.prefetch(@resources)
      end
    end
  end

  describe "when being initialized" do
    describe "with a hash" do
      before do
        @resource_class = double('resource_class')
        allow(provider_class).to receive(:resource_type).and_return(@resource_class)

        @property_class = double('property_class', :array_matching => :all, :superclass => Puppet::Property)
        allow(@resource_class).to receive(:attrclass).with(:one).and_return(@property_class)
        allow(@resource_class).to receive(:valid_parameter?).and_return(true)
      end

      it "should store a copy of the hash as its vlan_properties" do
        instance = provider_class.new(:device, :one => :two)
        expect(instance.former_properties).to eq({:one => :two})
      end
    end
  end

  describe "when an instance" do
    before do
      @instance = provider_class.new(:device)

      @property_class = double('property_class', :array_matching => :all, :superclass => Puppet::Property)
      @resource_class = double('resource_class', :attrclass => @property_class, :valid_parameter? => true, :validproperties => [:description])
      allow(provider_class).to receive(:resource_type).and_return(@resource_class)
    end

    it "should have a method for creating the instance" do
      expect(@instance).to respond_to(:create)
    end

    it "should have a method for removing the instance" do
      expect(@instance).to respond_to(:destroy)
    end

    it "should indicate when the instance already exists" do
      @instance = provider_class.new(:device, :ensure => :present)
      expect(@instance.exists?).to be_truthy
    end

    it "should indicate when the instance does not exist" do
      @instance = provider_class.new(:device, :ensure => :absent)
      expect(@instance.exists?).to be_falsey
    end

    describe "is being flushed" do
      it "should flush properties" do
        @instance = provider_class.new(:ensure => :present, :name => "200", :description => "myvlan")
        @instance.flush
        expect(@instance.properties).to be_empty
      end
    end

    describe "is being created" do
      before do
        @rclass = double('resource_class')
        allow(@rclass).to receive(:validproperties).and_return([:description])
        @resource = double('resource')
        allow(@resource).to receive(:class).and_return(@rclass)
        allow(@resource).to receive(:should).and_return(nil)
        allow(@instance).to receive(:resource).and_return(@resource)
      end

      it "should set its :ensure value to :present" do
        @instance.create
        expect(@instance.properties[:ensure]).to eq(:present)
      end

      it "should set all of the other attributes from the resource" do
        expect(@resource).to receive(:should).with(:description).and_return("myvlan")

        @instance.create
        expect(@instance.properties[:description]).to eq("myvlan")
      end
    end

    describe "is being destroyed" do
      it "should set its :ensure value to :absent" do
        @instance.destroy
        expect(@instance.properties[:ensure]).to eq(:absent)
      end
    end
  end
end
