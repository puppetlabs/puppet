#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:zypper)

describe provider_class do
  before(:each) do
    # Create a mock resource
    @resource = stub 'resource'

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name and source
    @resource.stubs(:[]).with(:name).returns "mypackage"
    @resource.stubs(:[]).with(:ensure).returns :installed
    @resource.stubs(:command).with(:zypper).returns "/usr/bin/zypper"

    @provider = provider_class.new(@resource)
  end

  it "should have an install method" do
    @provider = provider_class.new
    @provider.should respond_to(:install)
  end

  it "should have an uninstall method" do
    @provider = provider_class.new
    @provider.should respond_to(:uninstall)
  end

  it "should have an update method" do
    @provider = provider_class.new
    @provider.should respond_to(:update)
  end

  it "should have a latest method" do
    @provider = provider_class.new
    @provider.should respond_to(:latest)
  end

  describe "when installing with zypper version >= 1.0" do
    it "should use a command-line with versioned package'" do
      @resource.stubs(:should).with(:ensure).returns "1.2.3-4.5.6"
      @provider.stubs(:zypper_version).returns "1.2.8"

      @provider.expects(:zypper).with('--quiet', :install,
        '--auto-agree-with-licenses', '--no-confirm', 'mypackage-1.2.3-4.5.6')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end

    it "should use a command-line without versioned package" do
      @resource.stubs(:should).with(:ensure).returns :latest
      @provider.stubs(:zypper_version).returns "1.2.8"
      @provider.expects(:zypper).with('--quiet', :install,
        '--auto-agree-with-licenses', '--no-confirm', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end
  end

  describe "when installing with zypper version = 0.6.104" do
    it "should use a command-line with versioned package'" do
      @resource.stubs(:should).with(:ensure).returns "1.2.3-4.5.6"
      @provider.stubs(:zypper_version).returns "0.6.104"

      @provider.expects(:zypper).with('--terse', :install,
        '--auto-agree-with-licenses', '--no-confirm', 'mypackage-1.2.3-4.5.6')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end

    it "should use a command-line without versioned package" do
      @resource.stubs(:should).with(:ensure).returns :latest
      @provider.stubs(:zypper_version).returns "0.6.104"
      @provider.expects(:zypper).with('--terse', :install,
        '--auto-agree-with-licenses', '--no-confirm', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end
  end

  describe "when installing with zypper version = 0.6.13" do
    it "should use a command-line with versioned package'" do
      @resource.stubs(:should).with(:ensure).returns "1.2.3-4.5.6"
      @provider.stubs(:zypper_version).returns "0.6.13"

      @provider.expects(:zypper).with('--terse', :install,
        '--no-confirm', 'mypackage-1.2.3-4.5.6')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end

    it "should use a command-line without versioned package" do
      @resource.stubs(:should).with(:ensure).returns :latest
      @provider.stubs(:zypper_version).returns "0.6.13"
      @provider.expects(:zypper).with('--terse', :install,
        '--no-confirm', 'mypackage')
      @provider.expects(:query).returns "mypackage 0 1.2.3 4.5.6 x86_64"
      @provider.install
    end
  end

  describe "when updating" do
    it "should call install method of instance" do
      @provider.expects(:install)
      @provider.update
    end
  end

  describe "when getting latest version" do
    it "should return a version string with valid list-updates data from SLES11sp1" do
      fake_data = File.read(my_fixture('zypper-list-updates-SLES11sp1.out'))

      @resource.stubs(:[]).with(:name).returns "at"
      @provider.expects(:zypper).with("list-updates").returns fake_data
      @provider.latest.should == "3.1.8-1069.18.2"
    end
  end

end
