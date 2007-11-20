#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-11-20.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../../../spec_helper'

require 'puppet/provider/interface/redhat'


provider_class = Puppet::Type.type(:interface).provider(:redhat)

describe provider_class do
    it "should not be functional on systems without a network-scripts directory" do
        FileTest.expects(:exists?).with("/etc/sysconfig/network-scripts").returns(false)
        provider_class.should_not be_suitable
    end

    it "should be functional on systems with a network-scripts directory" do
        FileTest.expects(:exists?).with("/etc/sysconfig/network-scripts").returns(true)
        provider_class.should be_suitable
    end
end

describe provider_class, " when returning instances" do
    it "should consider each file in the network-scripts directory an interface instance" do
        Dir.expects(:glob).with("/etc/sysconfig/network-scripts/ifcfg-*").returns(%w{one two})
        one = {:name => "one"}
        two = {:name => "two"}
        Puppet::Type::Interface::ProviderRedhat.expects(:parse).with("one").returns(one)
        Puppet::Type::Interface::ProviderRedhat.expects(:parse).with("two").returns(two)
        Puppet::Type::Interface::ProviderRedhat.expects(:new).with(one).returns(:one)
        Puppet::Type::Interface::ProviderRedhat.expects(:new).with(two).returns(:two)
        Puppet::Type::Interface::ProviderRedhat.instances.should == [:one, :two]
    end
end

describe provider_class, " when parsing" do
    it "should return an unmodified provider if the file does not exist" do
        FileTest.expects(:exist?).with("/my/file").returns(false)
        provider = mock 'provider'
        Puppet::Type::Interface::ProviderRedhat.expects(:new).returns(provider)
        Puppet::Type::Interface::ProviderRedhat.parse("/my/file").should equal(provider)
    end

    it "should set each attribute in the file on the provider" do
        FileTest.expects(:exist?).with("/my/file").returns(true)
        File.expects(:readlines).with("/my/file").returns(%w{one=two three=four})
        provider = mock 'provider'
        Puppet::Type::Interface::ProviderRedhat.expects(:new).returns(provider)
        provider.expects(:one=).with('two')
        provider.expects(:three=).with('four')
        Puppet::Type::Interface::ProviderRedhat.parse("/my/file").should equal(provider)
    end
end

describe provider_class, " when setting the device to a value containing ':'" do
    before do
        @provider = Puppet::Type::Interface::ProviderRedhat.new
        @provider.device = "one:two"
    end
    it "should set the interface type to :alias" do
        @provider.interface_type.should == :alias
    end
    it "should set the interface to the string to the left of the ':'" do
        @provider.interface.should == "one"
    end
    it "should set the ifnum to the string to the right of the ':'" do
        @provider.ifnum.should == "two"
    end
end

describe provider_class, " when setting the device to a value starting with 'dummy-'" do
    before do
        @provider = Puppet::Type::Interface::ProviderRedhat.new
        @provider.device = "dummy5"
    end
    it "should set the interface type to :loopback" do
        @provider.interface_type.should == :loopback
    end
    it "should set the interface to 'dummy'" do
        @provider.interface.should == "dummy"
    end
    it "should set the ifnum to remainder of value after removing 'dummy'" do
        @provider.ifnum.should == "5"
    end
end

describe provider_class, " when setting the device to a value containing neither 'dummy-' nor ':'" do
    before do
        @provider = Puppet::Type::Interface::ProviderRedhat.new
        @provider.device = "whatever"
    end
    it "should set the interface type to :normal" do
        @provider.interface_type.should == :normal
    end
    it "should set the interface to the device value" do
        @provider.interface.should == "whatever"
    end
end

describe provider_class, " when setting the on_boot value" do
    before do
        @provider = Puppet::Type::Interface::ProviderRedhat.new
    end
    it "should set it to :true if the value is 'yes'" do
        @provider.on_boot = "yes"
        @provider.onboot.should == :true
    end
    it "should set it to :false if the value is not 'yes'" do
        @provider.on_boot = "no"
        @provider.onboot.should == :false
    end
end

describe provider_class, " when setting the ipaddr value" do
    before do
        @provider = Puppet::Type::Interface::ProviderRedhat.new
    end

    it "should set the name to the provided value" do
        @provider.ipaddr = "yay"
        @provider.name.should == "yay"
    end
end

describe provider_class, " when generating" do
    before do
        @provider = Puppet::Type::Interface::ProviderRedhat.new
        @provider.interface_type = :alias
        @provider.stubs(:device).returns("mydevice")
        @provider.stubs(:on_boot).returns("myboot")
        @provider.stubs(:name).returns("myname")
        @provider.stubs(:interface_type).returns("myname")
        @provider.stubs(:netmask).returns("mynetmask")

        @text = @provider.generate
    end

    it "should set the bootproto to none if the interface is an alias" do
        @text.should =~ /^BOOTPROTO=none$/
    end

    it "should set the bootproto to static if the interface is a loopback" do
        @provider.interface_type = :loopback
        @text = @provider.generate
        @text.should =~ /^BOOTPROTO=static$/
    end

    it "should set the broadcast address to nothing" do
        @text.should =~ /^BROADCAST=$/
    end

    it "should set the netmask to mynetmask" do
        @text.should =~ /^NETMASK=mynetmask$/
    end

    it "should set the device to the provider's device" do
        @text.should =~ /^DEVICE=mydevice$/
    end

    it "should set the onboot to the provider's on_boot value" do
        @text.should =~ /^ONBOOT=myboot$/
    end

    it "should set the ipaddr to the provider's name" do
        @text.should =~ /^IPADDR=myname$/
    end
end
