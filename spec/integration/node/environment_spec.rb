#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'
require 'puppet_spec/scope'

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

  shared_examples_for "the environment's initial import" do
    include PuppetSpec::Scope

    let(:node) { Puppet::Node.new('testnode') }

    it "a manifest referring to a directory invokes parsing of all its files in sorted order" do
      # fixture has three files 00_a.pp, 01_b.pp, and 02_c.pp. The 'b' file depends on 'a'
      # being evaluated first. The 'c' file is empty (to ensure empty things do not break the directory import).
      # if the files are evaluated in the wrong order, the file 'b' has a reference to $a (set in file 'a')
      # and with strict variable lookup should raise an error and fail this test.
      #
      dirname = my_fixture('sitedir')
      # Set the manifest to the directory to make it parse and combine them when compiling
      Puppet[:manifest] = dirname

      # include the classes that are in the fixture files
      node.stubs(:classes).returns(['a', 'b'])

      # compile, to make the initial_import in the environment take place the correct way
      catalog = Puppet::Parser::Compiler.compile(node)
      class_a = catalog.resource('Class[a]')
      class_b = catalog.resource('Class[b]')
      expect(class_a).to_not be_nil
      expect(class_b).to_not be_nil
    end
  end

  describe 'using classic parser' do
    before :each do
      Puppet[:parser] = 'current'
      # fixture uses variables that are set in a particular order (this ensures that files are parsed
      # and combined in the right order or an error will be raised if 'b' is evaluated before 'a').
      Puppet[:strict_variables] = true
    end
    it_behaves_like "the environment's initial import" do
    end
  end
  describe 'using future parser' do
    before :each do
      Puppet[:parser] = 'future'
      # Turned off because currently future parser turns on the binder which causes lookup of facts
      # that are uninitialized and it will fail with errors for 'osfamily' etc.
      # This can be turned back on when the binder is taken out of the equation.
      # Puppet[:strict_variables] = true
    end
    it_behaves_like "the environment's initial import" do
    end
end

end
