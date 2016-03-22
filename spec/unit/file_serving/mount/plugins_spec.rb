#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/file_serving/mount/plugins'

describe Puppet::FileServing::Mount::Plugins do
  before do
    @mount = Puppet::FileServing::Mount::Plugins.new("plugins")

    @environment = stub 'environment', :module => nil
    @options = { :recurse => true }
    @request = stub 'request', :environment => @environment, :options => @options
  end

  describe  "when finding files" do
    it "should use the provided environment to find the modules" do
      @environment.expects(:modules).returns []

      @mount.find("foo", @request)
    end

    it "should return nil if no module can be found with a matching plugin" do
      mod = mock 'module'
      mod.stubs(:plugin).with("foo/bar").returns nil

      @environment.stubs(:modules).returns [mod]
      expect(@mount.find("foo/bar", @request)).to be_nil
    end

    it "should return the file path from the module" do
      mod = mock 'module'
      mod.stubs(:plugin).with("foo/bar").returns "eh"

      @environment.stubs(:modules).returns [mod]
      expect(@mount.find("foo/bar", @request)).to eq("eh")
    end
  end

  describe "when searching for files" do
    it "should use the node's environment to find the modules" do
      @environment.expects(:modules).at_least_once.returns []
      @environment.stubs(:modulepath).returns ["/tmp/modules"]

      @mount.search("foo", @request)
    end

    it "should return modulepath if no modules can be found that have plugins" do
      mod = mock 'module'
      mod.stubs(:plugins?).returns false

      @environment.stubs(:modules).returns []
      @environment.stubs(:modulepath).returns ["/"]
      @options.expects(:[]=).with(:recurse, false)
      expect(@mount.search("foo/bar", @request)).to eq(["/"])
    end

    it "should return nil if no modules can be found that have plugins and modulepath is invalid" do
      mod = mock 'module'
      mod.stubs(:plugins?).returns false

      @environment.stubs(:modules).returns []
      @environment.stubs(:modulepath).returns []
      expect(@mount.search("foo/bar", @request)).to be_nil
    end

    it "should return the plugin paths for each module that has plugins" do
      one = stub 'module', :plugins? => true, :plugin_directory => "/one"
      two = stub 'module', :plugins? => true, :plugin_directory => "/two"

      @environment.stubs(:modules).returns [one, two]
      expect(@mount.search("foo/bar", @request)).to eq(%w{/one /two})
    end
  end
end
