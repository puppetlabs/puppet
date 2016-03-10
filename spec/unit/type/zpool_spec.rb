#! /usr/bin/env ruby
require 'spec_helper'

zpool = Puppet::Type.type(:zpool)

describe zpool do
  before do
    @provider = stub 'provider'
    @resource = stub 'resource', :resource => nil, :provider => @provider, :line => nil, :file => nil
  end

  properties = [:ensure, :disk, :mirror, :raidz, :spare, :log]

  properties.each do |property|
    it "should have a #{property} property" do
      expect(zpool.attrclass(property).ancestors).to be_include(Puppet::Property)
    end
  end

  parameters = [:pool, :raid_parity]

  parameters.each do |parameter|
    it "should have a #{parameter} parameter" do
      expect(zpool.attrclass(parameter).ancestors).to be_include(Puppet::Parameter)
    end
  end
end

vdev_property = Puppet::Property::VDev

describe vdev_property do
  before do
    vdev_property.initvars
    @resource = stub 'resource', :[]= => nil, :property => nil
    @property = vdev_property.new(:resource => @resource)
  end

  it "should be insync if the devices are the same" do
    @property.should = ["dev1 dev2"]
    expect(@property.safe_insync?(["dev2 dev1"])).to be_truthy
  end

  it "should be out of sync if the devices are not the same" do
    @property.should = ["dev1 dev3"]
    expect(@property.safe_insync?(["dev2 dev1"])).to be_falsey
  end

  it "should be insync if the devices are the same and the should values are comma separated" do
    @property.should = ["dev1", "dev2"]
    expect(@property.safe_insync?(["dev2 dev1"])).to be_truthy
  end

  it "should be out of sync if the device is absent and should has a value" do
    @property.should = ["dev1", "dev2"]
    expect(@property.safe_insync?(:absent)).to be_falsey
  end

  it "should be insync if the device is absent and should is absent" do
    @property.should = [:absent]
    expect(@property.safe_insync?(:absent)).to be_truthy
  end
end

multi_vdev_property = Puppet::Property::MultiVDev

describe multi_vdev_property do
  before do
    multi_vdev_property.initvars
    @resource = stub 'resource', :[]= => nil, :property => nil
    @property = multi_vdev_property.new(:resource => @resource)
  end

  it "should be insync if the devices are the same" do
    @property.should = ["dev1 dev2"]
    expect(@property.safe_insync?(["dev2 dev1"])).to be_truthy
  end

  it "should be out of sync if the devices are not the same" do
    @property.should = ["dev1 dev3"]
    expect(@property.safe_insync?(["dev2 dev1"])).to be_falsey
  end

  it "should be out of sync if the device is absent and should has a value" do
    @property.should = ["dev1", "dev2"]
    expect(@property.safe_insync?(:absent)).to be_falsey
  end

  it "should be insync if the device is absent and should is absent" do
    @property.should = [:absent]
    expect(@property.safe_insync?(:absent)).to be_truthy
  end

  describe "when there are multiple lists of devices" do
    it "should be in sync if each group has the same devices" do
      @property.should = ["dev1 dev2", "dev3 dev4"]
      expect(@property.safe_insync?(["dev2 dev1", "dev3 dev4"])).to be_truthy
    end

    it "should be out of sync if any group has the different devices" do
      @property.should = ["dev1 devX", "dev3 dev4"]
      expect(@property.safe_insync?(["dev2 dev1", "dev3 dev4"])).to be_falsey
    end

    it "should be out of sync if devices are in the wrong group" do
      @property.should = ["dev1 dev2", "dev3 dev4"]
      expect(@property.safe_insync?(["dev2 dev3", "dev1 dev4"])).to be_falsey
    end
  end
end
