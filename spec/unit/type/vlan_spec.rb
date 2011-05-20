#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:vlan) do

  it "should have a 'name' parameter'" do
    Puppet::Type.type(:vlan).new(:name => "200")[:name].should == "200"
  end

  it "should have a 'device_url' parameter'" do
    Puppet::Type.type(:vlan).new(:name => "200", :device_url => :device)[:device_url].should == :device
  end

  it "should be applied on device" do
    Puppet::Type.type(:vlan).new(:name => "200").should be_appliable_to_device
  end

  it "should have an ensure property" do
    Puppet::Type.type(:vlan).attrtype(:ensure).should == :property
  end

  it "should have a description property" do
    Puppet::Type.type(:vlan).attrtype(:description).should == :property
  end

  describe "when validating attribute values" do
    before do
      @provider = stub 'provider', :class => Puppet::Type.type(:vlan).defaultprovider, :clear => nil
      Puppet::Type.type(:vlan).defaultprovider.stubs(:new).returns(@provider)
    end

    it "should support :present as a value to :ensure" do
      Puppet::Type.type(:vlan).new(:name => "200", :ensure => :present)
    end

    it "should support :absent as a value to :ensure" do
      Puppet::Type.type(:vlan).new(:name => "200", :ensure => :absent)
    end

    it "should fail if vlan name is not a number" do
      lambda { Puppet::Type.type(:vlan).new(:name => "notanumber", :ensure => :present) }.should raise_error
    end
  end
end
