#!/usr/bin/env ruby

# Find and load the spec file.
Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

provider_class = Puppet::Type.type(:interface).provider(:redhat)

describe provider_class do
    describe "when returning instances" do
        before do
            Dir.stubs(:glob).with("/etc/sysconfig/network-scripts/ifcfg-*").returns(%w{/etc/sysconfig/network-scripts/ifcfg-eth0
                /etc/sysconfig/network-scripts/ifcfg-lo})
            FileTest.stubs(:exist?).returns true
            File.stubs(:readlines).with("/etc/sysconfig/network-scripts/ifcfg-eth0").returns %w{DEVICE=eth0\n BOOTPROTO=dhcp\n ONBOOT=yes\n TYPE=Ethernet\n
                USERCTL=yes\n PEERDNS=yes\n IPV6INIT=no\n }
            File.stubs(:readlines).with("/etc/sysconfig/network-scripts/ifcfg-lo").returns %w{DEVICE=lo\n IPADDR=127.0.0.1\n NETMASK=255.0.0.0\n NETWORK=127.0.0.0\n
                # If you're having problems with gated making 127.0.0.0/8 a martian,\n
                # you can change this to something else (255.255.255.255, for example)\n
                BROADCAST=127.255.255.255\n ONBOOT=yes\n NAME=loopback\n }
        end

        it "should succeed" do
            instances = nil
            lambda { instances = provider_class.instances }.should_not raise_error
        end

        it "should return provider instances for each file" do
            provider_class.instances[0].should be_instance_of(provider_class)
        end

        it "should return provider instances for each file" do
            provider_class.instances.length.should == 2
        end

        it "should set the name to the interface name extracted from the file" do
            instances = provider_class.instances
            instances[0].name.should == "eth0"
            instances[1].name.should == "lo"
        end
    end
end
