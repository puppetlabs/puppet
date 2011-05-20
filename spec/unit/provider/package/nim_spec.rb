#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:nim)

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

  it "should have an install method" do
    @provider = provider_class.new
    @provider.should respond_to(:install)
  end

  describe "when installing" do
    it "should install a package" do
      @resource.stubs(:should).with(:ensure).returns(:installed)
      @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets='mypackage'")
      @provider.install
    end

    it "should install a versioned package" do
      @resource.stubs(:should).with(:ensure).returns("1.2.3.4")
      @provider.expects(:nimclient).with("-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=mysource", "-a", "filesets='mypackage 1.2.3.4'")
      @provider.install
    end
  end
end
