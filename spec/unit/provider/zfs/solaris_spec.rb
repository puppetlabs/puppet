#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:zfs).provider(:solaris)

describe provider_class do
  before do
    @resource = stub("resource", :name => "myzfs")
    @resource.stubs(:[]).with(:name).returns "myzfs"
    @resource.stubs(:[]).returns "shouldvalue"
    @provider = provider_class.new(@resource)
  end

  it "should have a create method" do
    @provider.should respond_to(:create)
  end

  it "should have a destroy method" do
    @provider.should respond_to(:destroy)
  end

  it "should have an exists? method" do
    @provider.should respond_to(:exists?)
  end

  describe "when calling add_properties" do
    it "should add -o and the key=value for each properties with a value" do
      @resource.stubs(:[]).with(:quota).returns ""
      @resource.stubs(:[]).with(:refquota).returns ""
      @resource.stubs(:[]).with(:mountpoint).returns "/foo"
      properties = @provider.add_properties
      properties.include?("-o").should == true
      properties.include?("mountpoint=/foo").should == true
      properties.detect { |a| a.include?("quota") }.should == nil
    end
  end

  describe "when calling create" do
    it "should call add_properties" do
      @provider.stubs(:zfs)
      @provider.expects(:add_properties).returns([])
      @provider.create
    end

    it "should call zfs with create, properties and this zfs" do
      @provider.stubs(:add_properties).returns(%w{a b})
      @provider.expects(:zfs).with(:create, "a", "b", @resource[:name])
      @provider.create
    end
  end

  describe "when calling destroy" do
    it "should call zfs with :destroy and this zfs" do
      @provider.expects(:zfs).with(:destroy, @resource[:name])
      @provider.destroy
    end
  end

  describe "when calling exist?" do
    it "should call zfs with :list" do
      #return stuff because we have to slice and dice it
      @provider.expects(:zfs).with(:list).returns("NAME USED AVAIL REFER MOUNTPOINT\nmyzfs 100K 27.4M /myzfs")
      @provider.exists?
    end

    it "should return true if returned values match the name" do
      @provider.stubs(:zfs).with(:list).returns("NAME USED AVAIL REFER MOUNTPOINT\n#{@resource[:name]} 100K 27.4M /myzfs")
      @provider.exists?.should == true
    end

    it "should return false if returned values don't match the name" do
      @provider.stubs(:zfs).with(:list).returns("no soup for you")
      @provider.exists?.should == false
    end

  end

  [:mountpoint, :recordsize, :aclmode, :aclinherit, :primarycache, :secondarycache, :compression, :copies, :quota, :reservation, :sharenfs, :snapdir].each do |prop|
    describe "when getting the #{prop} value" do
      it "should call zfs with :get, #{prop} and this zfs" do
        @provider.expects(:zfs).with(:get, "-H", "-o", "value", prop, @resource[:name]).returns("value\n")
        @provider.send(prop)
      end

      it "should get the third value of the second line from the output" do
        @provider.stubs(:zfs).with(:get, "-H", "-o", "value", prop, @resource[:name]).returns("value\n")
        @provider.send(prop).should == "value"
      end
    end

    describe "when setting the #{prop} value" do
      it "should call zfs with :set, #{prop}=value and this zfs" do
        @provider.expects(:zfs).with(:set, "#{prop}=value", @resource[:name])
        @provider.send("#{prop}=".intern, "value")
      end
    end
  end

end
