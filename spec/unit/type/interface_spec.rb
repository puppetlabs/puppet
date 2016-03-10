#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:interface) do

  it "should have a 'name' parameter'" do
    expect(Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1")[:name]).to eq("FastEthernet 0/1")
  end

  it "should have a 'device_url' parameter'" do
    expect(Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :device_url => :device)[:device_url]).to eq(:device)
  end

  it "should have an ensure property" do
    expect(Puppet::Type.type(:interface).attrtype(:ensure)).to eq(:property)
  end

  it "should be applied on device" do
    expect(Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1")).to be_appliable_to_device
  end

  [:description, :speed, :duplex, :native_vlan, :encapsulation, :mode, :allowed_trunk_vlans, :etherchannel, :ipaddress].each do |p|
    it "should have a #{p} property" do
      expect(Puppet::Type.type(:interface).attrtype(p)).to eq(:property)
    end
  end

  describe "when validating attribute values" do
    before do
      @provider = stub 'provider', :class => Puppet::Type.type(:interface).defaultprovider, :clear => nil
      Puppet::Type.type(:interface).defaultprovider.stubs(:new).returns(@provider)
    end

    it "should support :present as a value to :ensure" do
      Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ensure => :present)
    end

    it "should support :shutdown as a value to :ensure" do
      Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ensure => :shutdown)
    end

    it "should support :no_shutdown as a value to :ensure" do
      Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ensure => :no_shutdown)
    end

    describe "especially speed" do
      it "should allow a number" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :speed => "100")
      end

      it "should allow :auto" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :speed => :auto)
      end
    end

    describe "especially duplex" do
      it "should allow :half" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :duplex => :half)
      end

      it "should allow :full" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :duplex => :full)
      end

      it "should allow :auto" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :duplex => :auto)
      end
    end

    describe "interface mode" do
      it "should allow :access" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :mode => :access)
      end

      it "should allow :trunk" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :mode => :trunk)
      end

      it "should allow 'dynamic auto'" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :mode => 'dynamic auto')
      end

      it "should allow 'dynamic desirable'" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :mode => 'dynamic desirable')
      end
    end

    describe "interface encapsulation" do
      it "should allow :dot1q" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :encapsulation => :dot1q)
      end

      it "should allow :isl" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :encapsulation => :isl)
      end

      it "should allow :negotiate" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :encapsulation => :negotiate)
      end
    end

    describe "especially ipaddress" do
      it "should allow ipv4 addresses" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ipaddress => "192.168.0.1/24")
      end

      it "should allow arrays of ipv4 addresses" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ipaddress => ["192.168.0.1/24", "192.168.1.0/24"])
      end

      it "should allow ipv6 addresses" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ipaddress => "f0e9::/64")
      end

      it "should allow ipv6 options" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ipaddress => "f0e9::/64 link-local")
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ipaddress => "f0e9::/64 eui-64")
      end

      it "should allow a mix of ipv4 and ipv6" do
        Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ipaddress => ["192.168.0.1/24", "f0e9::/64 link-local"])
      end

      it "should munge ip addresses to a computer format" do
        expect(Puppet::Type.type(:interface).new(:name => "FastEthernet 0/1", :ipaddress => "192.168.0.1/24")[:ipaddress]).to eq([[24, IPAddr.new('192.168.0.1'), nil]])
      end
    end
  end
end
