#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/network_device/cisco/device'
require 'puppet/util/network_device/transport/telnet'

if Puppet.features.telnet?
  describe Puppet::Util::NetworkDevice::Cisco::Device do
    before(:each) do
      @transport = stub_everything 'transport', :is_a? => true, :command => ""
      @cisco = Puppet::Util::NetworkDevice::Cisco::Device.new("telnet://user:password@localhost:23/")
      @cisco.transport = @transport
    end

    describe "when creating the device" do
      it "should find the enable password from the url" do
        cisco = Puppet::Util::NetworkDevice::Cisco::Device.new("telnet://user:password@localhost:23/?enable=enable_password")
        expect(cisco.enable_password).to eq("enable_password")
      end

      describe "decoding the enable password" do
        it "should not parse a password if no query is given" do
          cisco = described_class.new("telnet://user:password@localhost:23")
          expect(cisco.enable_password).to be_nil
        end

        it "should not parse a password if no enable param is given" do
          cisco = described_class.new("telnet://user:password@localhost:23/?notenable=notapassword")
          expect(cisco.enable_password).to be_nil
        end
        it "should decode sharps" do
          cisco = described_class.new("telnet://user:password@localhost:23/?enable=enable_password%23with_a_sharp")
          expect(cisco.enable_password).to eq("enable_password#with_a_sharp")
        end

        it "should decode spaces" do
          cisco = described_class.new("telnet://user:password@localhost:23/?enable=enable_password%20with_a_space")
          expect(cisco.enable_password).to eq("enable_password with_a_space")
        end

        it "should only use the query parameter" do
          cisco = described_class.new("telnet://enable=:password@localhost:23/?enable=enable_password&notenable=notapassword")
          expect(cisco.enable_password).to eq("enable_password")
        end
      end

      it "should find the enable password from the options" do
        cisco = Puppet::Util::NetworkDevice::Cisco::Device.new("telnet://user:password@localhost:23/?enable=enable_password", :enable_password => "mypass")
        expect(cisco.enable_password).to eq("mypass")
      end

      it "should find the debug mode from the options" do
        Puppet::Util::NetworkDevice::Transport::Telnet.expects(:new).with(true).returns(@transport)
        Puppet::Util::NetworkDevice::Cisco::Device.new("telnet://user:password@localhost:23", :debug => true)
      end

      it "should set the debug mode to nil by default" do
        Puppet::Util::NetworkDevice::Transport::Telnet.expects(:new).with(nil).returns(@transport)
        Puppet::Util::NetworkDevice::Cisco::Device.new("telnet://user:password@localhost:23")
      end
    end

    describe "when connecting to the physical device" do
      it "should connect to the transport" do
        @transport.expects(:connect)
        @cisco.command
      end

      it "should attempt to login" do
        @cisco.expects(:login)
        @cisco.command
      end

      it "should tell the device to not page" do
        @transport.expects(:command).with("terminal length 0")
        @cisco.command
      end

      it "should enter the enable password if returned prompt is not privileged" do
        @transport.stubs(:command).yields("Switch>").returns("")
        @cisco.expects(:enable)
        @cisco.command
      end

      it "should find device capabilities" do
        @cisco.expects(:find_capabilities)
        @cisco.command
      end

      it "should execute given command" do
        @transport.expects(:command).with("mycommand")
        @cisco.command("mycommand")
      end

      it "should yield to the command block if one is provided" do
        @transport.expects(:command).with("mycommand")
        @cisco.command do |c|
          c.command("mycommand")
        end
      end

      it "should close the device transport" do
        @transport.expects(:close)
        @cisco.command
      end

      describe "when login in" do
        it "should not login if transport handles login" do
          @transport.expects(:handles_login?).returns(true)
          @transport.expects(:command).never
          @transport.expects(:expect).never
          @cisco.login
        end

        it "should send username if one has been provided" do
          @transport.expects(:command).with("user", :prompt => /^Password:/)
          @cisco.login
        end

        it "should send password after the username" do
          @transport.expects(:command).with("user", :prompt => /^Password:/)
          @transport.expects(:command).with("password")
          @cisco.login
        end

        it "should expect the Password: prompt if no user was sent" do
          @cisco.url.user = ''
          @transport.expects(:expect).with(/^Password:/)
          @transport.expects(:command).with("password")
          @cisco.login
        end
      end

      describe "when entering enable password" do
        it "should raise an error if no enable password has been set" do
          @cisco.enable_password = nil
          expect{ @cisco.enable }.to raise_error(RuntimeError, /Can't issue "enable" to enter privileged/)
        end

        it "should send the enable command and expect an enable prompt" do
          @cisco.enable_password = 'mypass'
          @transport.expects(:command).with("enable", :prompt => /^Password:/)
          @cisco.enable
        end

        it "should send the enable password" do
          @cisco.enable_password = 'mypass'
          @transport.stubs(:command).with("enable", :prompt => /^Password:/)
          @transport.expects(:command).with("mypass")
          @cisco.enable
        end
      end
    end

    describe "when finding network device capabilities" do
      it "should try to execute sh vlan brief" do
        @transport.expects(:command).with("sh vlan brief").returns("")
        @cisco.find_capabilities
      end

      it "should detect errors" do
        @transport.stubs(:command).with("sh vlan brief").returns(<<eos)
Switch#sh vlan brief  
% Ambiguous command:  "sh vlan brief"
Switch#
eos

        @cisco.find_capabilities
        expect(@cisco).not_to be_support_vlan_brief
      end
    end


    {
      "Fa 0/1" => "FastEthernet0/1",
      "Fa0/1" => "FastEthernet0/1",
      "FastEth 0/1" => "FastEthernet0/1",
      "Gi1" => "GigabitEthernet1",
      "Te2" => "TenGigabitEthernet2",
      "Di9" => "Dialer9",
      "Ethernet 0/0/1" => "Ethernet0/0/1",
      "E0" => "Ethernet0",
      "ATM 0/1.1" => "ATM0/1.1",
      "VLAN99" => "VLAN99"
    }.each do |input,expected|
      it "should canonicalize #{input} to #{expected}" do
        expect(@cisco.canonicalize_ifname(input)).to eq(expected)
      end
    end

    describe "when updating device vlans" do
      describe "when removing a vlan" do
        it "should issue the no vlan command" do
          @transport.expects(:command).with("no vlan 200")
          @cisco.update_vlan("200", {:ensure => :present, :name => "200"}, { :ensure=> :absent})
        end
      end

      describe "when updating a vlan" do
        it "should issue the vlan command to enter global vlan modifications" do
          @transport.expects(:command).with("vlan 200")
          @cisco.update_vlan("200", {:ensure => :present, :name => "200"}, { :ensure=> :present, :name => "200"})
        end

        it "should issue the name command to modify the vlan description" do
          @transport.expects(:command).with("name myvlan")
          @cisco.update_vlan("200", {:ensure => :present, :name => "200"}, { :ensure=> :present, :name => "200", :description => "myvlan"})
        end
      end
    end

    describe "when parsing interface" do

      it "should parse interface output" do
        @cisco.expects(:parse_interface).returns({ :ensure => :present })

        expect(@cisco.interface("FastEthernet0/1")).to eq({ :ensure => :present })
      end

      it "should parse trunking and merge results" do
        @cisco.stubs(:parse_interface).returns({ :ensure => :present })
        @cisco.expects(:parse_trunking).returns({ :native_vlan => "100" })

        expect(@cisco.interface("FastEthernet0/1")).to eq({ :ensure => :present, :native_vlan => "100" })
      end

      it "should return an absent interface if parse_interface returns nothing" do
        @cisco.stubs(:parse_interface).returns({})

        expect(@cisco.interface("FastEthernet0/1")).to eq({ :ensure => :absent })
      end

      it "should parse ip address information and merge results" do
        @cisco.stubs(:parse_interface).returns({ :ensure => :present })
        @cisco.expects(:parse_interface_config).returns({ :ipaddress => [24,IPAddr.new('192.168.0.24'), nil] })

        expect(@cisco.interface("FastEthernet0/1")).to eq({ :ensure => :present, :ipaddress => [24,IPAddr.new('192.168.0.24'), nil] })
      end

      it "should parse the sh interface command" do
        @transport.stubs(:command).with("sh interface FastEthernet0/1").returns(<<eos)
Switch#sh interfaces FastEthernet 0/1
FastEthernet0/1 is down, line protocol is down 
  Hardware is Fast Ethernet, address is 00d0.bbe2.19c1 (bia 00d0.bbe2.19c1)
  MTU 1500 bytes, BW 100000 Kbit, DLY 100 usec, 
     reliability 255/255, txload 1/255, rxload 1/255
  Encapsulation ARPA, loopback not set
  Keepalive not set
  Auto-duplex , Auto Speed , 100BaseTX/FX
  ARP type: ARPA, ARP Timeout 04:00:00
  Last input never, output 5d04h, output hang never
  Last clearing of "show interface" counters never
  Queueing strategy: fifo
  Output queue 0/40, 0 drops; input queue 0/75, 0 drops
  5 minute input rate 0 bits/sec, 0 packets/sec
  5 minute output rate 0 bits/sec, 0 packets/sec
     580 packets input, 54861 bytes
     Received 6 broadcasts, 0 runts, 0 giants, 0 throttles
     0 input errors, 0 CRC, 0 frame, 0 overrun, 0 ignored
     0 watchdog, 1 multicast
     0 input packets with dribble condition detected
     845 packets output, 80359 bytes, 0 underruns
     0 output errors, 0 collisions, 1 interface resets
     0 babbles, 0 late collision, 0 deferred
     0 lost carrier, 0 no carrier
     0 output buffer failures, 0 output buffers swapped out
Switch#
eos

        expect(@cisco.parse_interface("FastEthernet0/1")).to eq({ :ensure => :absent, :duplex => :auto, :speed => :auto })
      end

      it "should be able to parse the sh vlan brief command output" do
        @cisco.stubs(:support_vlan_brief?).returns(true)
        @transport.stubs(:command).with("sh vlan brief").returns(<<eos)
Switch#sh vlan brief
VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
1    default                          active    Fa0/3, Fa0/4, Fa0/5, Fa0/6,
                                                Fa0/7, Fa0/8, Fa0/9, Fa0/10,
                                                Fa0/11, Fa0/12, Fa0/13, Fa0/14,
                                                Fa0/15, Fa0/16, Fa0/17, Fa0/18,
                                                Fa0/23, Fa0/24
10   VLAN0010                         active    
100  management                       active    Fa0/1, Fa0/2
Switch#
eos

        expect(@cisco.parse_vlans).to eq({"100"=>{:status=>"active", :interfaces=>["FastEthernet0/1", "FastEthernet0/2"], :description=>"management", :name=>"100"}, "1"=>{:status=>"active", :interfaces=>["FastEthernet0/3", "FastEthernet0/4", "FastEthernet0/5", "FastEthernet0/6", "FastEthernet0/7", "FastEthernet0/8", "FastEthernet0/9", "FastEthernet0/10", "FastEthernet0/11", "FastEthernet0/12", "FastEthernet0/13", "FastEthernet0/14", "FastEthernet0/15", "FastEthernet0/16", "FastEthernet0/17", "FastEthernet0/18", "FastEthernet0/23", "FastEthernet0/24"], :description=>"default", :name=>"1"}, "10"=>{:status=>"active", :interfaces=>[], :description=>"VLAN0010", :name=>"10"}})
      end

      it "should parse trunk switchport information" do
        @transport.stubs(:command).with("sh interface FastEthernet0/21 switchport").returns(<<eos)
Switch#sh interfaces FastEthernet 0/21 switchport
Name: Fa0/21
Switchport: Enabled
Administrative mode: trunk
Operational Mode: trunk
Administrative Trunking Encapsulation: dot1q
Operational Trunking Encapsulation: dot1q
Negotiation of Trunking: Disabled
Access Mode VLAN: 0 ((Inactive))
Trunking Native Mode VLAN: 1 (default)
Trunking VLANs Enabled: ALL
Trunking VLANs Active: 1,10,100
Pruning VLANs Enabled: 2-1001

Priority for untagged frames: 0
Override vlan tag priority: FALSE
Voice VLAN: none
Appliance trust: none
Self Loopback: No
Switch#
eos

        expect(@cisco.parse_trunking("FastEthernet0/21")).to eq({ :mode => :trunk, :encapsulation => :dot1q, :native_vlan => "1", :allowed_trunk_vlans=>:all, })
      end

      it "should parse dynamic desirable switchport information with native and allowed vlans" do
        @transport.stubs(:command).with("sh interface GigabitEthernet 0/1 switchport").returns(<<eos)
c2960#sh interfaces GigabitEthernet 0/1 switchport 
Name: Gi0/1
Switchport: Enabled
Administrative Mode: dynamic desirable
Operational Mode: trunk
Administrative Trunking Encapsulation: dot1q
Operational Trunking Encapsulation: dot1q
Negotiation of Trunking: On
Access Mode VLAN: 100 (SHDSL)
Trunking Native Mode VLAN: 1 (default)
Administrative Native VLAN tagging: enabled
Voice VLAN: none
Administrative private-vlan host-association: none 
Administrative private-vlan mapping: none 
Administrative private-vlan trunk native VLAN: none
Administrative private-vlan trunk Native VLAN tagging: enabled
Administrative private-vlan trunk encapsulation: dot1q
Administrative private-vlan trunk normal VLANs: none
Administrative private-vlan trunk associations: none
Administrative private-vlan trunk mappings: none
Operational private-vlan: none
Trunking VLANs Enabled: 1,99
Pruning VLANs Enabled: 2-1001
Capture Mode Disabled
Capture VLANs Allowed: ALL

Protected: false
Unknown unicast blocked: disabled
Unknown multicast blocked: disabled
Appliance trust: none
c2960#
eos

        expect(@cisco.parse_trunking("GigabitEthernet 0/1")).to eq({ :mode => "dynamic desirable", :encapsulation => :dot1q, :access_vlan => "100", :native_vlan => "1", :allowed_trunk_vlans=>"1,99", })
      end

      it "should parse access switchport information" do
        @transport.stubs(:command).with("sh interface FastEthernet0/1 switchport").returns(<<eos)
Switch#sh interfaces FastEthernet 0/1 switchport  
Name: Fa0/1
Switchport: Enabled
Administrative mode: static access
Operational Mode: static access
Administrative Trunking Encapsulation: isl
Operational Trunking Encapsulation: isl
Negotiation of Trunking: Disabled
Access Mode VLAN: 100 (SHDSL)
Trunking Native Mode VLAN: 1 (default)
Trunking VLANs Enabled: NONE
Pruning VLANs Enabled: NONE

Priority for untagged frames: 0
Override vlan tag priority: FALSE
Voice VLAN: none
Appliance trust: none
Self Loopback: No
Switch#
eos

        expect(@cisco.parse_trunking("FastEthernet0/1")).to eq({ :mode => :access, :access_vlan => "100", :native_vlan => "1" })
      end

      it "should parse auto/negotiate switchport information" do
        @transport.stubs(:command).with("sh interface FastEthernet0/24 switchport").returns(<<eos)
Switch#sh interfaces FastEthernet 0/24 switchport
Name: Fa0/24
Switchport: Enabled
Administrative mode: dynamic auto
Operational Mode: static access
Administrative Trunking Encapsulation: negotiate
Operational Trunking Encapsulation: native
Negotiation of Trunking: On
Access Mode VLAN: 1 (default)
Trunking Native Mode VLAN: 2 (default)
Administrative Native VLAN tagging: enabled
Voice VLAN: none
Administrative private-vlan host-association: none
Administrative private-vlan mapping: none
Administrative private-vlan trunk native VLAN: none
Administrative private-vlan trunk Native VLAN tagging: enabled
Administrative private-vlan trunk encapsulation: dot1q
Administrative private-vlan trunk normal VLANs: none
Administrative private-vlan trunk private VLANs: none
Operational private-vlan: none
Trunking VLANs Enabled: ALL
Pruning VLANs Enabled: 2-1001
Capture Mode Disabled
Capture VLANs Allowed: ALL

Protected: false
Unknown unicast blocked: disabled
Unknown multicast blocked: disabled
Appliance trust: none
eos

        expect(@cisco.parse_trunking("FastEthernet0/24")).to eq({ :mode => "dynamic auto", :encapsulation => :negotiate, :allowed_trunk_vlans => :all, :access_vlan => "1", :native_vlan => "2" })
      end

      it "should parse ip addresses" do
        @transport.stubs(:command).with("sh running-config interface Vlan 1 | begin interface").returns(<<eos)
router#sh running-config interface Vlan 1 | begin interface
interface Vlan1
 description $ETH-SW-LAUNCH$$INTF-INFO-HWIC 4ESW$$FW_INSIDE$
 ip address 192.168.0.24 255.255.255.0 secondary
 ip address 192.168.0.1 255.255.255.0
 ip access-group 100 in
 no ip redirects
 no ip proxy-arp
 ip nbar protocol-discovery
 ip dns view-group dow
 ip nat inside
 ip virtual-reassembly
 ip route-cache flow
 ipv6 address 2001:7A8:71C1::/64 eui-64
 ipv6 enable
 ipv6 traffic-filter DENY-ACL6 out
 ipv6 mtu 1280
 ipv6 nd prefix 2001:7A8:71C1::/64
 ipv6 nd ra interval 60
 ipv6 nd ra lifetime 180
 ipv6 verify unicast reverse-path
 ipv6 inspect STD6 out
end

router#
eos
        expect(@cisco.parse_interface_config("Vlan 1")).to eq({:ipaddress=>[[24, IPAddr.new('192.168.0.24'), 'secondary'],
                                                                        [24, IPAddr.new('192.168.0.1'), nil],
                                                                        [64, IPAddr.new('2001:07a8:71c1::'), "eui-64"]]})
      end

      it "should parse etherchannel membership" do
        @transport.stubs(:command).with("sh running-config interface Gi0/17 | begin interface").returns(<<eos)
c2960#sh running-config interface Gi0/17 | begin interface
interface GigabitEthernet0/17
 description member of Po1
 switchport mode access
 channel-protocol lacp
 channel-group 1 mode passive
 spanning-tree portfast
 spanning-tree bpduguard enable
end

c2960#
eos
        expect(@cisco.parse_interface_config("Gi0/17")).to eq({:etherchannel=>"1"})
      end
    end

    describe "when finding device facts" do
      it "should delegate to the cisco facts entity" do
        facts = stub 'facts'
        Puppet::Util::NetworkDevice::Cisco::Facts.expects(:new).returns(facts)

        facts.expects(:retrieve).returns(:facts)

        expect(@cisco.facts).to eq(:facts)
      end
    end

  end
end
