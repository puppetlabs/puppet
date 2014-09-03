#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'
require 'puppet_spec/scope'
require 'matchers/resource'

describe Puppet::Node::Environment do
  include PuppetSpec::Files
  include Matchers::Resource

  def a_module_in(name, dir)
    Dir.mkdir(dir)
    moddir = File.join(dir, name)
    Dir.mkdir(moddir)
    moddir
  end

  it "should be able to return each module from its environment with the environment, name, and path set correctly" do
    base = tmpfile("env_modules")
    Dir.mkdir(base)

    dirs = []
    mods = {}
    %w{1 2}.each do |num|
      dir = File.join(base, "dir#{num}")
      dirs << dir

      mods["mod#{num}"] = a_module_in("mod#{num}", dir)
    end

    environment = Puppet::Node::Environment.create(:foo, dirs)

    environment.modules.each do |mod|
      mod.environment.should == environment
      mod.path.should == mods[mod.name]
    end
  end

  it "should not yield the same module from different module paths" do
    base = tmpfile("env_modules")
    Dir.mkdir(base)

    dirs = []
    %w{1 2}.each do |num|
      dir = File.join(base, "dir#{num}")
      dirs << dir

      a_module_in("mod", dir)
    end

    environment = Puppet::Node::Environment.create(:foo, dirs)

    mods = environment.modules
    mods.length.should == 1
    mods[0].path.should == File.join(base, "dir1", "mod")
  end

  shared_examples_for "the environment's initial import" do |settings|
    it "a manifest referring to a directory invokes parsing of all its files in sorted order" do
      settings.each do |name, value|
        Puppet[name] = value
      end

      # fixture has three files 00_a.pp, 01_b.pp, and 02_c.pp. The 'b' file
      # depends on 'a' being evaluated first. The 'c' file is empty (to ensure
      # empty things do not break the directory import).
      #
      dirname = my_fixture('sitedir')

      # Set the manifest to the directory to make it parse and combine them when compiling
      node = Puppet::Node.new('testnode',
                              :environment => Puppet::Node::Environment.create(:testing, [], dirname))

      catalog = Puppet::Parser::Compiler.compile(node)

      expect(catalog).to have_resource('Class[A]')
      expect(catalog).to have_resource('Class[B]')
      expect(catalog).to have_resource('Notify[variables]').with_parameter(:message, "a: 10, b: 10")
    end
  end

  shared_examples_for "the environment's initial import in the future" do |settings|
    it "a manifest referring to a directory invokes recursive parsing of all its files in sorted order" do
      settings.each do |name, value|
        Puppet[name] = value
      end

      # fixture has three files 00_a.pp, 01_b.pp, and 02_c.pp. The 'b' file
      # depends on 'a' being evaluated first. The 'c' file is empty (to ensure
      # empty things do not break the directory import).
      #
      dirname = my_fixture('sitedir2')

      # Set the manifest to the directory to make it parse and combine them when compiling
      node = Puppet::Node.new('testnode',
                              :environment => Puppet::Node::Environment.create(:testing, [], dirname))

      catalog = Puppet::Parser::Compiler.compile(node)

      expect(catalog).to have_resource('Class[A]')
      expect(catalog).to have_resource('Class[B]')
      expect(catalog).to have_resource('Notify[variables]').with_parameter(:message, "a: 10, b: 10 c: 20")
    end
  end

  describe 'using classic parser' do
    it_behaves_like "the environment's initial import",
      :parser => 'current',
      # fixture uses variables that are set in a particular order (this ensures
      # that files are parsed and combined in the right order or an error will
      # be raised if 'b' is evaluated before 'a').
      :strict_variables => true
  end

  describe 'using future parser' do
    it_behaves_like "the environment's initial import",
      :parser    => 'future',
      # Turned off because currently future parser turns on the binder which
      # causes lookup of facts that are uninitialized and it will fail with
      # errors for 'osfamily' etc.  This can be turned back on when the binder
      # is taken out of the equation.
      :strict_variables => false
  end
end
