require 'spec_helper'

require 'puppet/util/network_device'
require 'puppet/util/network_device/cisco/interface'

describe Puppet::Util::NetworkDevice::Cisco::Interface do
  before(:each) do
    @transport = double('transport', command: nil)
    @interface = Puppet::Util::NetworkDevice::Cisco::Interface.new("FastEthernet0/1",@transport)
  end

  it "should include IPCalc" do
    @interface.class.include?(Puppet::Util::NetworkDevice::IPCalc)
  end

  describe "when updating the physical device" do
    it "should enter global configuration mode" do
      expect(@transport).to receive(:command).with("conf t")
      @interface.update
    end

    it "should enter interface configuration mode" do
      expect(@transport).to receive(:command).with("interface FastEthernet0/1")
      @interface.update
    end

    it "should 'execute' all differing properties" do
      expect(@interface).to receive(:execute).with(:description, "b")
      expect(@interface).not_to receive(:execute).with(:mode, :access)
      @interface.update({ :description => "a", :mode => :access }, { :description => "b", :mode => :access })
    end

    it "should execute in cisco ios defined order" do
      set_speed = false
      set_duplex = false
      allow(@interface).to receive(:execute) do |*args|
        if set_speed
          expect(args).to eq([:duplex, :auto])
          set_duplex = true
        else
          expect(args).to eq([:speed, :auto])
          set_speed = true
        end
      end

      @interface.update({ :duplex => :half, :speed => "10" }, { :duplex => :auto, :speed => :auto  })
      expect(set_speed).to eq(true)
      expect(set_duplex).to eq(true)
    end

    it "should execute absent properties with a no prefix" do
      expect(@interface).to receive(:execute).with(:description, "a", "no ")
      @interface.update({ :description => "a"}, { })
    end

    it "should exit twice" do
      expect(@transport).to receive(:command).with("exit").twice
      @interface.update
    end
  end

  describe "when executing commands" do
    it "should execute string commands directly" do
      expect(@transport).to receive(:command).with("speed auto")
      @interface.execute(:speed, :auto)
    end

    it "should execute string commands with the given prefix" do
      expect(@transport).to receive(:command).with("no speed auto")
      @interface.execute(:speed, :auto, "no ")
    end

    it "should stop at executing the first command that works for array" do
      expect(@transport).to receive(:command).with("channel-group 1").and_yield("% Invalid command")
      expect(@transport).to receive(:command).with("port group 1")
      @interface.execute(:etherchannel, "1")
    end

    it "should execute the block for block commands" do
      expect(@transport).to receive(:command).with("ip address 192.168.0.1 255.255.255.0")
      @interface.execute(:ipaddress, [[24, IPAddr.new('192.168.0.1'), nil]])
    end

    it "should execute the block for block commands" do
      expect(@transport).to receive(:command).with("ipv6 address fe08::/76 link-local")
      @interface.execute(:ipaddress, [[76, IPAddr.new('fe08::'), 'link-local']])
    end
  end

  describe "when sending commands to the device" do
    it "should detect errors" do
      expect(Puppet).to receive(:err)
      allow(@transport).to receive(:command).and_yield("% Invalid Command")
      @interface.command("sh ver")
    end
  end
end
