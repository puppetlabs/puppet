#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:aix)

describe provider_class do
  before(:each) do
    # Create a mock resource
    @resource = stub 'resource'

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name and source
    @resource.stubs(:[]).with(:name).returns "mypackage"
    @resource.stubs(:[]).with(:source).returns "mysource"
    @resource.stubs(:[]).with(:ensure).returns :installed

    @provider = provider_class.new
    @provider.resource = @resource
  end

  [:install, :uninstall, :latest, :query, :update].each do |method|
    it "should have a #{method} method" do
      @provider.should respond_to(method)
    end
  end

  it "should uninstall a package" do
    @provider.expects(:installp).with('-gu', 'mypackage')
    @provider.uninstall
  end

  describe "when installing" do
    it "should install a package" do
      @resource.stubs(:should).with(:ensure).returns(:installed)
      @provider.expects(:installp).with('-acgwXY', '-d', 'mysource', 'mypackage')
      @provider.install
    end

    it "should install a specific package version" do
      @resource.stubs(:should).with(:ensure).returns("1.2.3.4")
      @provider.expects(:installp).with('-acgwXY', '-d', 'mysource', 'mypackage 1.2.3.4')
      @provider.install
    end
  end

  describe "when finding the latest version" do
    it "should return the current version when no later version is present" do
      @provider.stubs(:latest_info).returns(nil)
      @provider.stubs(:properties).returns( { :ensure => "1.2.3.4" } )
      @provider.latest.should == "1.2.3.4"
    end

    it "should return the latest version of a package" do
      @provider.stubs(:latest_info).returns( { :version => "1.2.3.5" } )
      @provider.latest.should == "1.2.3.5"
    end
  end

  it "update should install a package" do
    @provider.expects(:install).with(false)
    @provider.update
  end
end
