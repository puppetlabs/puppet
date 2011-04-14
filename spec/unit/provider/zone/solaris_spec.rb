#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:zone).provider(:solaris)

describe provider_class do
  before do
    @resource = stub("resource", :name => "mypool")
    @resource.stubs(:[]).returns "shouldvalue"
    @provider = provider_class.new(@resource)
  end

  describe "when calling configure" do
    it "should add the create args to the create str" do
      @resource.stubs(:properties).returns([])
      @resource.stubs(:[]).with(:create_args).returns("create_args")
      @provider.expects(:setconfig).with("create -b create_args\nset zonepath=shouldvalue\ncommit\n")
      @provider.configure
    end
  end

  describe "when installing" do
    it "should call zoneadm" do
      @provider.expects(:zoneadm)
      @provider.install
    end

    describe "when cloning" do
      before { @resource.stubs(:[]).with(:clone).returns(:clone_argument) }

      it "sohuld clone with the resource's clone attribute" do
        @provider.expects(:zoneadm).with(:clone, :clone_argument)
        @provider.install
      end
    end

    describe "when not cloning" do
      before { @resource.stubs(:[]).with(:clone).returns(nil)}

      it "should just install if there are no install args" do
        @resource.stubs(:[]).with(:install_args).returns(nil)
        @provider.expects(:zoneadm).with(:install)
        @provider.install
      end

      it "should add the install args to the command if they exist" do
        @resource.stubs(:[]).with(:install_args).returns("install args")
        @provider.expects(:zoneadm).with(:install, ["install", "args"])
        @provider.install
      end
    end
  end

end
