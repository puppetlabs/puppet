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
      Puppet::Type.type(:service).new(:name => "foo", :provider => :upstart)
    end

    let :provider do
      provider_class.new(resource)
    end

    let :init_script do
      PuppetSpec::Files.tmpfile("foo.conf")
    end

    let :disabled_content do
      "\t #  \t start on\nother file stuff"
    end

    let :multiline_disabled do
      "# \t  start on other file stuff (\n" +
       "#   more stuff ( # )))))inline comment\n" +
       "#   finishing up )\n" +
       "#   and done )\n" +
       "this line shouldn't be touched\n"
    end

    let :multiline_enabled do
      " \t  start on other file stuff (\n" +
       "   more stuff ( # )))))inline comment\n" +
       "   finishing up )\n" +
       "   and done )\n" +
       "this line shouldn't be touched\n"
    end

    let :enabled_content do
      "\t   \t start on\nother file stuff"
    end

    let :content do
      "just some text"
    end

    before(:each) do
      provider.stubs(:is_upstart?).returns(true)
      provider.stubs(:search).returns(init_script)
    end

    [:enabled?,:enable,:disable].each do |enableable|
      it "should respond to #{enableable}" do
        provider.should respond_to(enableable)
      end
    end

    describe "when enabling" do
      it "should open and uncomment the '#start on' line" do
        file = File.open(init_script, 'w')
        file.write(disabled_content)
        file.close
        provider.enable
        File.open(init_script).read.should == enabled_content
      end

      it "should add a 'start on' line if none exists" do
        file = File.open(init_script, 'w')
        file.write("this is a file")
        file.close
        provider.enable
        File.open(init_script).read.should == "this is a file\nstart on runlevel [2,3,4,5]"
      end

      it "should do nothing if already enabled" do
        file = File.open(init_script, 'w')
        file.write(enabled_content)
        file.close
        provider.enable
        File.open(init_script).read.should == enabled_content
      end

      it "should handle multiline 'start on' stanzas" do
        file = File.open(init_script, 'w')
        file.write(multiline_disabled)
        file.close
        provider.enable
        File.open(init_script).read.should == multiline_enabled
      end
    end

    describe "when disabling" do
      it "should open and comment the 'start on' line" do
        file = File.open(init_script, 'w')
        file.write(enabled_content)
        file.close
        provider.disable
        File.open(init_script).read.should == "#" + enabled_content
      end

      it "should do nothing if already disabled" do
        file = File.open(init_script, 'w')
        file.write(disabled_content)
        file.close
        provider.disable
        File.open(init_script).read.should == disabled_content
      end

      it "should handle multiline 'start on' stanzas" do
        file = File.open(init_script, 'w')
        file.write(multiline_enabled)
        file.close
        provider.disable
        File.open(init_script).read.should == multiline_disabled
      end
    end

    describe "when checking whether it is enabled" do
      it "should consider 'start on ...' to be enabled" do
        file = File.open(init_script, 'w')
        file.write(enabled_content)
        file.close
        provider.enabled?.should == :true
      end

      it "should consider '#start on ...' to be disabled" do
        file = File.open(init_script, 'w')
        file.write(disabled_content)
        file.close
        provider.enabled?.should == :false
      end

      it "should consider no start on line to be disabled" do
        file = File.open(init_script, 'w')
        file.write(content)
        file.close
        provider.enabled?.should == :false
      end
    end
  end
end
