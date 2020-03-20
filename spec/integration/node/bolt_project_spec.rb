require 'spec_helper'
require 'puppet_spec/files'

describe Puppet::Node::BoltProject do
  include PuppetSpec::Files

  def a_module_in(name, dir)
    FileUtils.mkdir_p(File.join(dir, name))[0]
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
    mods[File.basename(Dir.pwd)] = Dir.pwd

    project = Puppet::Node::BoltProject.create(:foo, Dir.pwd, dirs)

    project.modules.each do |mod|
      expect(mod.environment).to eq(project)
      expect(mod.path).to eq(mods[mod.name])
    end
  end

  it "should not yield the same module from project dir and modulepath" do
    base = tmpfile("env_modules")
    Dir.mkdir(base)

    dir = File.join(base, "no_dup")
    a_module_in(File.basename(Dir.pwd), "no_dup")
    project = Puppet::Node::BoltProject.create(:foo, Dir.pwd, [dir])

    mods = project.modules
    expect(mods.length).to eq(1)
    expect(mods[0].path).to eq(Dir.pwd)
  end

  it "should include the current directory as a module" do
    project = Puppet::Node::BoltProject.create(:foo, Dir.pwd, [])

    mods = project.modules
    expect(mods.length).to eq(1)
    expect(mods[0].path).to eq(Dir.pwd)
  end
end
