#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/file_serving/mount/modules'

describe Puppet::FileServing::Mount::Modules, "when finding files" do
    before do
        @mount = Puppet::FileServing::Mount::Modules.new("modules")

        @environment = stub 'environment', :module => nil
        @mount.stubs(:environment).returns @environment
    end

    it "should use the node's environment to find the module" do
        env = mock 'env'
        @mount.expects(:environment).with("mynode").returns env
        env.expects(:module)

        @mount.find("foo", :node => "mynode")
    end

    it "should treat the first field of the relative path as the module name" do
        @environment.expects(:module).with("foo")
        @mount.find("foo/bar/baz")
    end

    it "should return nil if the specified module does not exist" do
        @environment.expects(:module).with("foo").returns nil
        @mount.find("foo/bar/baz")
    end

    it "should return the file path from the module" do
        mod = mock 'module'
        mod.expects(:file).with("bar/baz").returns "eh"
        @environment.expects(:module).with("foo").returns mod
        @mount.find("foo/bar/baz").should == "eh"
    end
end

describe Puppet::FileServing::Mount::Modules, "when searching for files" do
    before do
        @mount = Puppet::FileServing::Mount::Modules.new("modules")

        @environment = stub 'environment', :module => nil
        @mount.stubs(:environment).returns @environment
    end

    it "should use the node's environment to search the module" do
        env = mock 'env'
        @mount.expects(:environment).with("mynode").returns env
        env.expects(:module)

        @mount.search("foo", :node => "mynode")
    end

    it "should treat the first field of the relative path as the module name" do
        @environment.expects(:module).with("foo")
        @mount.search("foo/bar/baz")
    end

    it "should return nil if the specified module does not exist" do
        @environment.expects(:module).with("foo").returns nil
        @mount.search("foo/bar/baz")
    end

    it "should return the file path as an array from the module" do
        mod = mock 'module'
        mod.expects(:file).with("bar/baz").returns "eh"
        @environment.expects(:module).with("foo").returns mod
        @mount.search("foo/bar/baz").should == ["eh"]
    end
end
