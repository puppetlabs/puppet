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
      expect(mod.environment).to eq(environment)
      expect(mod.path).to eq(mods[mod.name])
    end
  end

  it "should expand 8.3 paths on Windows when creating an environment",
    :if => Puppet::Util::Platform.windows? do

    # asking for short names only works on paths that exist
    base = Puppet::Util::Windows::File.get_short_pathname(tmpdir("env_modules"))
    parent_modules_dir = File.join(base, 'testmoduledir')

    # make sure the paths have ~ in them, indicating unexpanded 8.3 paths
    expect(parent_modules_dir).to match(/~/)

    module_dir = a_module_in('testmodule', parent_modules_dir)

    # create the environment with unexpanded 8.3 paths
    environment = Puppet::Node::Environment.create(:foo, [parent_modules_dir])

    # and expect fully expanded paths inside the environment
    # necessary for comparing module paths internally by the parser
    expect(environment.modulepath).to eq([Puppet::FileSystem.expand_path(parent_modules_dir)])
    expect(environment.modules.first.path).to eq(Puppet::FileSystem.expand_path(module_dir))
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
    expect(mods.length).to eq(1)
    expect(mods[0].path).to eq(File.join(base, "dir1", "mod"))
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

  shared_examples_for "the environment's initial import in 4x" do |settings|
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

  describe 'using 4x parser' do
    it_behaves_like "the environment's initial import",
      # fixture uses variables that are set in a particular order (this ensures
      # that files are parsed and combined in the right order or an error will
      # be raised if 'b' is evaluated before 'a').
      :strict_variables => true
  end

  describe 'using 4x parser' do
    it_behaves_like "the environment's initial import in 4x",
      # fixture uses variables that are set in a particular order (this ensures
      # that files are parsed and combined in the right order or an error will
      # be raised if 'b' is evaluated before 'a').
      :strict_variables => true
  end

  describe "#extralibs on Windows", :if => Puppet.features.microsoft_windows? do

    describe "with UTF8 characters in PUPPETLIB" do
      let(:rune_utf8) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }

      before { Puppet::Util::Windows::Process.set_environment_variable('PUPPETLIB', rune_utf8) }

      it "should use UTF8 characters in PUPPETLIB environment variable" do
        expect(Puppet::Node::Environment.extralibs()).to eq([rune_utf8])
      end
    end
  end
end
