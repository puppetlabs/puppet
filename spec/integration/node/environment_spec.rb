#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet_spec/files'

describe Puppet::Node::Environment do
  include PuppetSpec::Files

  it "should be able to return each module from its environment with the environment, name, and path set correctly" do
    base = tmpfile("env_modules")
    Dir.mkdir(base)

    dirs = []
    mods = {}
    %w{1 2}.each do |num|
      dir = File.join(base, "dir#{num}")
      dirs << dir
      Dir.mkdir(dir)
      mod = "mod#{num}"
      moddir = File.join(dir, mod)
      mods[mod] = moddir
      Dir.mkdir(moddir)
    end

    environment = Puppet::Node::Environment.new("foo")
    environment.stubs(:modulepath).returns dirs

    environment.modules.each do |mod|
      mod.environment.should == environment
      mod.path.should == mods[mod.name]
    end
  end

  it "should not yield the same module from different module paths" do
    base = tmpfile("env_modules")
    Dir.mkdir(base)

    dirs = []
    mods = {}
    %w{1 2}.each do |num|
      dir = File.join(base, "dir#{num}")
      dirs << dir
      Dir.mkdir(dir)
      mod = "mod"
      moddir = File.join(dir, mod)
      mods[mod] = moddir
      Dir.mkdir(moddir)
    end

    environment = Puppet::Node::Environment.new("foo")
    environment.stubs(:modulepath).returns dirs

    mods = environment.modules
    mods.length.should == 1
    mods[0].path.should == File.join(base, "dir1", "mod")
  end
end
