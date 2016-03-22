#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/network_device'
require 'puppet/util/network_device/cisco/facts'

describe Puppet::Util::NetworkDevice::Cisco::Facts do
  before(:each) do
    @transport = stub_everything 'transport'
    @facts = Puppet::Util::NetworkDevice::Cisco::Facts.new(@transport)
  end

  {
    "cisco WS-C2924C-XL (PowerPC403GA) processor (revision 0x11) with 8192K/1024K bytes of memory." => {:hardwaremodel => "WS-C2924C-XL", :memorysize => "8192K", :processor => "PowerPC403GA", :hardwarerevision => "0x11" },
    "Cisco 1841 (revision 5.0) with 355328K/37888K bytes of memory." => {:hardwaremodel=>"1841", :memorysize => "355328K", :hardwarerevision => "5.0" },
    "Cisco 877 (MPC8272) processor (revision 0x200) with 118784K/12288K bytes of memory." => {:hardwaremodel=>"877", :memorysize => "118784K", :processor => "MPC8272", :hardwarerevision => "0x200" },
    "cisco WS-C2960G-48TC-L (PowerPC405) processor (revision C0) with 61440K/4088K bytes of memory." => {:hardwaremodel=>"WS-C2960G-48TC-L", :memorysize => "61440K", :processor => "PowerPC405", :hardwarerevision => "C0" },
    "cisco WS-C2950T-24 (RC32300) processor (revision R0) with 19959K bytes of memory." => {:hardwaremodel=>"WS-C2950T-24", :memorysize => "19959K", :processor => "RC32300", :hardwarerevision => "R0" }
  }.each do |ver, expected|
    it "should parse show ver output for hardware device facts" do
      @transport.stubs(:command).with("sh ver").returns(<<eos)
Switch>sh ver
#{ver}
Switch>
eos
      expect(@facts.parse_show_ver).to eq(expected)
    end
  end

  {
"Switch uptime is 1 year, 12 weeks, 6 days, 22 hours, 32 minutes" => { :hostname => "Switch", :uptime => "1 year, 12 weeks, 6 days, 22 hours, 32 minutes", :uptime_seconds => 39393120, :uptime_days => 455 },
"c2950 uptime is 3 weeks, 1 day, 23 hours, 36 minutes" => { :hostname => "c2950", :uptime => "3 weeks, 1 day, 23 hours, 36 minutes", :uptime_days => 22, :uptime_seconds =>  1985760},
"router uptime is 5 weeks, 1 day, 3 hours, 30 minutes" => { :hostname => "router", :uptime => "5 weeks, 1 day, 3 hours, 30 minutes", :uptime_days => 36, :uptime_seconds => 3123000 },
"c2950 uptime is 1 minute" => { :hostname => "c2950", :uptime => "1 minute", :uptime_days => 0, :uptime_seconds => 60 },
"c2950 uptime is 20 weeks, 6 minutes" => { :hostname => "c2950", :uptime=>"20 weeks, 6 minutes", :uptime_seconds=>12096360, :uptime_days=>140 },
"c2950 uptime is 2 years, 20 weeks, 6 minutes" => { :hostname => "c2950", :uptime=>"2 years, 20 weeks, 6 minutes", :uptime_seconds=>75168360, :uptime_days=>870 }
  }.each do |ver, expected|
    it "should parse show ver output for device uptime facts" do
      @transport.stubs(:command).with("sh ver").returns(<<eos)
Switch>sh ver
#{ver}
Switch>
eos
      expect(@facts.parse_show_ver).to eq(expected)
    end
  end

  {
"IOS (tm) C2900XL Software (C2900XL-C3H2S-M), Version 12.0(5)WC10, RELEASE SOFTWARE (fc1)"=> { :operatingsystem => "IOS", :operatingsystemrelease => "12.0(5)WC10", :operatingsystemmajrelease => "12.0WC", :operatingsystemfeature => "C3H2S"},
"IOS (tm) C2950 Software (C2950-I6K2L2Q4-M), Version 12.1(22)EA8a, RELEASE SOFTWARE (fc1)"=> { :operatingsystem => "IOS", :operatingsystemrelease => "12.1(22)EA8a", :operatingsystemmajrelease => "12.1EA", :operatingsystemfeature => "I6K2L2Q4"},
"Cisco IOS Software, C2960 Software (C2960-LANBASEK9-M), Version 12.2(44)SE, RELEASE SOFTWARE (fc1)"=>{ :operatingsystem => "IOS", :operatingsystemrelease => "12.2(44)SE", :operatingsystemmajrelease => "12.2SE", :operatingsystemfeature => "LANBASEK9"},
"Cisco IOS Software, C870 Software (C870-ADVIPSERVICESK9-M), Version 12.4(11)XJ4, RELEASE SOFTWARE (fc2)"=>{ :operatingsystem => "IOS", :operatingsystemrelease => "12.4(11)XJ4", :operatingsystemmajrelease => "12.4XJ", :operatingsystemfeature => "ADVIPSERVICESK9"},
"Cisco IOS Software, 1841 Software (C1841-ADVSECURITYK9-M), Version 12.4(24)T4, RELEASE SOFTWARE (fc2)" =>{ :operatingsystem => "IOS", :operatingsystemrelease => "12.4(24)T4", :operatingsystemmajrelease => "12.4T", :operatingsystemfeature => "ADVSECURITYK9"},
  }.each do |ver, expected|
    it "should parse show ver output for device software version facts" do
      @transport.stubs(:command).with("sh ver").returns(<<eos)
Switch>sh ver
#{ver}
Switch>
eos
      expect(@facts.parse_show_ver).to eq(expected)
    end
  end
end
