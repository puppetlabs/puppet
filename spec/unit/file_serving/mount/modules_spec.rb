#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/file_serving/mount/modules'

describe Puppet::FileServing::Mount::Modules do
  before do
    @mount = Puppet::FileServing::Mount::Modules.new("modules")

    @environment = stub 'environment', :module => nil
    @request = stub 'request', :environment => @environment
  end

  describe "when finding files" do
    it "should use the provided environment to find the module" do
      @environment.expects(:module)

      @mount.find("foo", @request)
    end

    it "should treat the first field of the relative path as the module name" do
      @environment.expects(:module).with("foo")
      @mount.find("foo/bar/baz", @request)
    end

    it "should return nil if the specified module does not exist" do
      @environment.expects(:module).with("foo").returns nil
      @mount.find("foo/bar/baz", @request)
    end

    it "should return the file path from the module" do
      mod = mock 'module'
      mod.expects(:file).with("bar/baz").returns "eh"
      @environment.expects(:module).with("foo").returns mod
      @mount.find("foo/bar/baz", @request).should == "eh"
    end
  end

  describe "when searching for files" do
    it "should use the node's environment to search the module" do
      @environment.expects(:module)

      @mount.search("foo", @request)
    end

    it "should treat the first field of the relative path as the module name" do
      @environment.expects(:module).with("foo")
      @mount.search("foo/bar/baz", @request)
    end

    it "should return nil if the specified module does not exist" do
      @environment.expects(:module).with("foo").returns nil
      @mount.search("foo/bar/baz", @request)
    end

    it "should return the file path as an array from the module" do
      mod = mock 'module'
      mod.expects(:file).with("bar/baz").returns "eh"
      @environment.expects(:module).with("foo").returns mod
      @mount.search("foo/bar/baz", @request).should == ["eh"]
    end
  end
end
