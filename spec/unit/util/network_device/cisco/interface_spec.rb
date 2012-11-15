#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/network_device'
require 'puppet/util/network_device/cisco/interface'

describe Puppet::Util::NetworkDevice::Cisco::Interface do
  before(:each) do
    @transport = stub_everything 'transport'
    @interface = Puppet::Util::NetworkDevice::Cisco::Interface.new("FastEthernet0/1",@transport)
  end

  it "should include IPCalc" do
    @interface.class.include?(Puppet::Util::NetworkDevice::IPCalc)
  end

  describe "when updating the physical device" do
    it "should enter global configuration mode" do
      @transport.expects(:command).with("conf t")
      @interface.update
    end

    it "should enter interface configuration mode" do
      @transport.expects(:command).with("interface FastEthernet0/1")
      @interface.update
    end

    it "should 'execute' all differing properties" do
      @interface.expects(:execute).with(:description, "b")
      @interface.expects(:execute).with(:mode, :access).never
      @interface.update({ :description => "a", :mode => :access }, { :description => "b", :mode => :access })
    end

    it "should execute in cisco ios defined order" do
      speed = states('speed').starts_as('notset')
      @interface.expects(:execute).with(:speed, :auto).then(speed.is('set'))
      @interface.expects(:execute).with(:duplex, :auto).when(speed.is('set'))
      @interface.update({ :duplex => :half, :speed => "10" }, { :duplex => :auto, :speed => :auto  })
    end

    it "should execute absent properties with a no prefix" do
      @interface.expects(:execute).with(:description, "a", "no ")
      @interface.update({ :description => "a"}, { })
    end

    it "should exit twice" do
      @transport.expects(:command).with("exit").twice
      @interface.update
    end
  end

  describe "when executing commands" do
    it "should execute string commands directly" do
      @transport.expects(:command).with("speed auto")
      @interface.execute(:speed, :auto)
    end

    it "should execute string commands with the given prefix" do
      @transport.expects(:command).with("no speed auto")
      @interface.execute(:speed, :auto, "no ")
    end

    it "should stop at executing the first command that works for array" do
      @transport.expects(:command).with("channel-group 1").yields("% Invalid command")
      @transport.expects(:command).with("port group 1")
      @interface.execute(:etherchannel, "1")
    end

    it "should execute the block for block commands" do
      @transport.expects(:command).with("ip address 192.168.0.1 255.255.255.0")
      @interface.execute(:ipaddress, [[24, IPAddr.new('192.168.0.1'), nil]])
    end

    it "should execute the block for block commands" do
      @transport.expects(:command).with("ipv6 address fe08::/76 link-local")
      @interface.execute(:ipaddress, [[76, IPAddr.new('fe08::'), 'link-local']])
    end

  end

  describe "when sending commands to the device" do
    it "should detect errors" do
      Puppet.expects(:err)
      @transport.stubs(:command).yields("% Invalid Command")
      @interface.command("sh ver")
    end
  end
end
