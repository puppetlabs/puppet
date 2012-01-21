#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/network_device/config'

describe Puppet::Util::NetworkDevice::Config do
  include PuppetSpec::Files

  before(:each) do
    Puppet[:deviceconfig] = make_absolute("/dummy")
    FileTest.stubs(:exists?).with(make_absolute("/dummy")).returns(true)
  end

  describe "when initializing" do
    before :each do
      Puppet::Util::NetworkDevice::Config.any_instance.stubs(:read)
    end

    it "should use the deviceconfig setting as pathname" do
      Puppet.expects(:[]).with(:deviceconfig).returns(make_absolute("/dummy"))

      Puppet::Util::NetworkDevice::Config.new
    end

    it "should raise an error if no file is defined finally" do
      Puppet.expects(:[]).with(:deviceconfig).returns(nil)

      lambda { Puppet::Util::NetworkDevice::Config.new }.should raise_error(Puppet::DevError)
    end

    it "should read and parse the file" do
      Puppet::Util::NetworkDevice::Config.any_instance.expects(:read)

      Puppet::Util::NetworkDevice::Config.new
    end
  end

  describe "when parsing device" do
    before :each do
      @config = Puppet::Util::NetworkDevice::Config.new
      @config.stubs(:changed?).returns(true)
      @fd = stub 'fd'
      File.stubs(:open).yields(@fd)
    end

    it "should skip comments" do
      @fd.stubs(:each).yields('  # comment')

      OpenStruct.expects(:new).never

      @config.read
    end

    it "should increment line number even on commented lines" do
      @fd.stubs(:each).multiple_yields('  # comment','[router.puppetlabs.com]')

      @config.read
      @config.devices.should be_include('router.puppetlabs.com')
    end

    it "should skip blank lines" do
      @fd.stubs(:each).yields('  ')

      @config.read
      @config.devices.should be_empty
    end

    it "should produce the correct line number" do
      @fd.stubs(:each).multiple_yields('  ', '[router.puppetlabs.com]')

      @config.read
      @config.devices['router.puppetlabs.com'].line.should == 2
    end

    it "should throw an error if the current device already exists" do
      @fd.stubs(:each).multiple_yields('[router.puppetlabs.com]', '[router.puppetlabs.com]')

      lambda { @config.read }.should raise_error
    end

    it "should accept device certname containing dashes" do
      @fd.stubs(:each).yields('[router-1.puppetlabs.com]')

      @config.read
      @config.devices.should include('router-1.puppetlabs.com')
    end

    it "should create a new device for each found device line" do
      @fd.stubs(:each).multiple_yields('[router.puppetlabs.com]', '[swith.puppetlabs.com]')

      @config.read
      @config.devices.size.should == 2
    end

    it "should parse the device type" do
      @fd.stubs(:each).multiple_yields('[router.puppetlabs.com]', 'type cisco')

      @config.read
      @config.devices['router.puppetlabs.com'].provider.should == 'cisco'
    end

    it "should parse the device url" do
      @fd.stubs(:each).multiple_yields('[router.puppetlabs.com]', 'type cisco', 'url ssh://test/')

      @config.read
      @config.devices['router.puppetlabs.com'].url.should == 'ssh://test/'
    end
  end

end
