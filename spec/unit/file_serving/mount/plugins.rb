#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'
require 'puppet/file_serving/mount/plugins'

describe Puppet::FileServing::Mount::Plugins, "when finding files" do
    before do
        @mount = Puppet::FileServing::Mount::Plugins.new("modules")
    end

    it "should use the provided environment to find the modules" do
        env = mock 'env'
        env.expects(:modules).returns []

        @mount.find("foo", env)
    end

    it "should return nil if no module can be found with a matching plugin" do
        mod = mock 'module'
        mod.stubs(:plugin).with("foo/bar").returns nil

        env = stub 'env', :modules => []
        @mount.find("foo/bar", env).should be_nil
    end

    it "should return the file path from the module" do
        mod = mock 'module'
        mod.stubs(:plugin).with("foo/bar").returns "eh"

        env = stub 'env', :modules => [mod]
        @mount.find("foo/bar", env).should == "eh"
    end
end

describe Puppet::FileServing::Mount::Plugins, "when searching for files" do
    before do
        @mount = Puppet::FileServing::Mount::Plugins.new("modules")
    end

    it "should use the node's environment to find the modules" do
        env = mock 'env'
        env.expects(:modules).returns []

        @mount.search("foo", env)
    end

    it "should return nil if no modules can be found that have plugins" do
        mod = mock 'module'
        mod.stubs(:plugins?).returns false

        env = stub 'env', :modules => []
        @mount.search("foo/bar", env).should be_nil
    end

    it "should return the plugin paths for each module that has plugins" do
        one = stub 'module', :plugins? => true, :plugin_directory => "/one"
        two = stub 'module', :plugins? => true, :plugin_directory => "/two"

        env = stub 'env', :modules => [one, two]
        @mount.search("foo/bar", env).should == %w{/one /two}
    end
end
