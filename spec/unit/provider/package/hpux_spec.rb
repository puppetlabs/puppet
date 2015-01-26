#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:hpux)

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
    @provider.stubs(:resource).returns @resource
  end

  it "should have an install method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:install)
  end

  it "should have an uninstall method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:uninstall)
  end

  it "should have a swlist method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:swlist)
  end

  describe "when installing" do
    it "should use a command-line like 'swinstall -x mount_all_filesystems=false -s SOURCE PACKAGE-NAME'" do
      @provider.expects(:swinstall).with('-x', 'mount_all_filesystems=false', '-s', 'mysource', 'mypackage')
      @provider.install
    end
  end

  describe "when uninstalling" do
    it "should use a command-line like 'swremove -x mount_all_filesystems=false PACKAGE-NAME'" do
      @provider.expects(:swremove).with('-x', 'mount_all_filesystems=false', 'mypackage')
      @provider.uninstall
    end
  end
end
