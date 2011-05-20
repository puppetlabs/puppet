#!/usr/bin/env rspec
require 'spec_helper'

property = Puppet::Type.type(:file).attrclass(:owner)

describe property do
  before do
    # FIXME: many of these tests exercise the provider rather than `owner`
    # and should be moved into provider tests. ~JW
    @provider = Puppet::Type.type(:file).provider(:posix).new
    @provider.stubs(:uid).with("one").returns(1)

    @resource = stub 'resource', :line => "foo", :file => "bar"
    @resource.stubs(:[]).returns "foo"
    @resource.stubs(:[]).with(:path).returns "/my/file"
    @resource.stubs(:provider).returns @provider

    @owner = property.new :resource => @resource
  end

  it "should have a method for testing whether an owner is valid" do
    @provider.must respond_to(:validuser?)
  end

  it "should return the found uid if an owner is valid" do
    @provider.expects(:uid).with("foo").returns 500
    @provider.validuser?("foo").should == 500
  end

  it "should return false if an owner is not valid" do
    @provider.expects(:uid).with("foo").returns nil
    @provider.validuser?("foo").should be_false
  end

  describe "when retrieving the current value" do
    it "should return :absent if the file cannot stat" do
      @resource.expects(:stat).returns nil

      @owner.retrieve.should == :absent
    end

    it "should get the uid from the stat instance from the file" do
      stat = stub 'stat', :ftype => "foo"
      @resource.expects(:stat).returns stat
      stat.expects(:uid).returns 500

      @owner.retrieve.should == 500
    end

    it "should warn and return :silly if the found value is higher than the maximum uid value" do
      Puppet.settings.expects(:value).with(:maximum_uid).returns 500

      stat = stub 'stat', :ftype => "foo"
      @resource.expects(:stat).returns stat
      stat.expects(:uid).returns 1000

      @provider.expects(:warning)
      @owner.retrieve.should == :silly
    end
  end

  describe "when determining if the file is in sync" do
    describe "and not running as root" do
      it "should warn once and return true" do
        Puppet.features.expects(:root?).returns false

        @provider.expects(:warnonce)

        @owner.should = [10]
        @owner.must be_safe_insync(20)
      end
    end

    before do
      Puppet.features.stubs(:root?).returns true
    end

    it "should be in sync if 'should' is not provided" do
      @owner.must be_safe_insync(10)
    end

    it "should directly compare the owner values if the desired owner is an integer" do
      @owner.should = [10]
      @owner.must be_safe_insync(10)
    end

    it "should treat numeric strings as integers" do
      @owner.should = ["10"]
      @owner.must be_safe_insync(10)
    end

    it "should convert the owner name to an integer if the desired owner is a string" do
      @provider.expects(:uid).with("foo").returns 10
      @owner.should = %w{foo}

      @owner.must be_safe_insync(10)
    end

    it "should not validate that users exist when a user is specified as an integer" do
      @provider.expects(:uid).never
      @provider.validuser?(10)
    end

    it "should fail if it cannot convert an owner name to an integer" do
      @provider.expects(:uid).with("foo").returns nil
      @owner.should = %w{foo}

      lambda { @owner.safe_insync?(10) }.should raise_error(Puppet::Error)
    end

    it "should return false if the owners are not equal" do
      @owner.should = [10]
      @owner.should_not be_safe_insync(20)
    end
  end

  describe "when changing the owner" do
    before do
      @owner.should = %w{one}
      @owner.stubs(:path).returns "path"
      @owner.stubs(:uid).returns 500
    end

    it "should chown the file if :links is set to :follow" do
      @resource.expects(:[]).with(:links).returns :follow
      File.expects(:chown)

      @owner.sync
    end

    it "should lchown the file if :links is set to :manage" do
      @resource.expects(:[]).with(:links).returns :manage
      File.expects(:lchown)

      @owner.sync
    end

    it "should use the first valid owner in its 'should' list" do
      @owner.should = %w{one two three}
      @provider.expects(:validuser?).with("one").returns nil
      @provider.expects(:validuser?).with("two").returns 500
      @provider.expects(:validuser?).with("three").never

      File.expects(:chown).with(500, nil, "/my/file")

      @owner.sync
    end
  end
end
