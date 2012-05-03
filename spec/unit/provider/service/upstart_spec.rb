#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:upstart)

describe provider_class do
  describe "#instances" do
    it "should be able to find all instances" do
      processes = ["rc stop/waiting", "ssh start/running, process 712"].join("\n")
      provider_class.stubs(:execpipe).yields(processes)
      provider_class.instances.map {|provider| provider.name}.should =~ ["rc","ssh"]
    end

    it "should attach the interface name for network interfaces" do
      processes = ["network-interface (eth0)"].join("\n")
      provider_class.stubs(:execpipe).yields(processes)
      provider_class.instances.first.name.should == "network-interface INTERFACE=eth0"
    end
  end

  describe "#status" do
    it "should allow the user to override the status command" do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart, :status => "/bin/foo")
      provider = provider_class.new(resource)

      # Because we stub execution, we also need to stub the result of it, or a
      # previously failing command execution will cause this test to do the
      # wrong thing.
      provider.expects(:ucommand)
      $?.stubs(:exitstatus).returns(0)
      provider.status.should == :running
    end

    it "should use the default status command if none is specified" do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
      provider = provider_class.new(resource)
      provider.stubs(:is_upstart?).returns(true)

      provider.expects(:status_exec).with(["foo"]).returns("foo start/running, process 1000")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      provider.status.should == :running
    end

    it "should properly handle services with 'start' in their name" do
      resource = Puppet::Type.type(:service).new(:name => "foostartbar", :provider => :upstart)
      provider = provider_class.new(resource)
      provider.stubs(:is_upstart?).returns(true)

      provider.expects(:status_exec).with(["foostartbar"]).returns("foostartbar stop/waiting")
      Process::Status.any_instance.stubs(:exitstatus).returns(0)
      provider.status.should == :stopped
    end
  end
  describe "inheritance" do
    let :resource do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
    end

    let :provider do
      provider = provider_class.new(resource)
    end

    describe "when upstart job" do
      before(:each) do
        provider.stubs(:is_upstart?).returns(true)
      end
      ["start", "stop"].each do |command|
        it "should return the #{command}cmd of its parent provider" do
          provider.send("#{command}cmd".to_sym).should == [provider.command(command.to_sym), resource.name]
        end
      end
      it "should return nil for the statuscmd" do
        provider.statuscmd.should be_nil
      end
    end

    describe "when init script" do
      before(:each) do
        provider.stubs(:is_upstart?).returns(false)
      end
      ["start", "stop", "status"].each do |command|
        it "should return the #{command}cmd of its parent provider" do
          provider.expects(:search).with('foo').returns("/etc/init.d/foo")
          provider.send("#{command}cmd".to_sym).should == ["/etc/init.d/foo", command.to_sym]
        end
      end
    end
  end

  describe "should be enableable" do
    let :resource do
      resource = Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
    end

    let :provider do
      provider = provider_class.new(resource)
    end

    before(:each) do
      provider.stubs(:is_upstart?).returns(true)
    end

    [:enabled?,:enable,:disable].each do |enableable|
      it "should respond to #{enableable}" do
        provider.should respond_to(enableable)
      end
    end

    describe "when enabling" do
      it "should open and uncomment the '#start on' line" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:open).returns file
        file.stubs(:read).returns "#start on bar"
        file.expects(:write).with("start on bar")
        file.expects(:close)
        provider.enable
      end

      it "should add a 'start on' line if none exists" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:open).returns file
        file.stubs(:read).returns "a line without leading start on"
        file.expects(:write).with("a line without leading start on\nstart on runlevel [2,3,4,5]")
        file.expects(:close)
        provider.enable
      end

      it "should do nothing if already enabled" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:open).returns file
        file.stubs(:read).returns "start on bar"
        file.expects(:write).with("start on bar")
        file.expects(:close)
        provider.enable
      end
    end

    describe "when disabling" do
      it "should open and comment the 'start on' line" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:open).returns file
        file.stubs(:read).returns "start on bar"
        file.expects(:write).with("#start on bar")
        file.expects(:close)
        provider.disable
      end

      it "should do nothing if already disabled" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:open).returns file
        file.stubs(:read).returns "#start on bar"
        file.expects(:write).with("#start on bar")
        file.expects(:close)
        provider.disable
      end
    end

    describe "when checking whether it is enabled" do
      it "should consider 'start on ...' to be enabled" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:read).returns "start on bar"
        provider.enabled?.should == :true
      end

      it "should consider '#start on ...' to be disabled" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:read).returns "#start on bar"
        provider.enabled?.should == :false
      end

      it "should consider no start on line to be disabled" do
        file = stub 'file'
        File.expects(:join).with("/etc/init", "foo.conf")
        File.stubs(:read).returns "just a line with some text"
        provider.enabled?.should == :false
      end
    end
  end
end
