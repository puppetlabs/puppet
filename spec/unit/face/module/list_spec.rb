require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module list" do
  include PuppetSpec::Files

  before do
    dir = tmpdir("deep_path")

    @modpath1 = File.join(dir, "modpath1")
    @modpath2 = File.join(dir, "modpath2")

    FileUtils.mkdir_p(@modpath1)
    FileUtils.mkdir_p(@modpath2)
  end

  def mkmodule(name, path)
    mod_path = File.join(path, name)
    FileUtils.mkdir_p(mod_path)
    mod_path
  end

  it "should return an empty list per dir in path if there are no modules" do
    Puppet.settings[:modulepath] = "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}"
    Puppet::Face[:module, :current].list.should == {
      @modpath1 => [],
      @modpath2 => []
    }
  end

  it "should include modules separated by the environment's modulepath" do
    foomod1 = mkmodule('foo', @modpath1)
    barmod1 = mkmodule('bar', @modpath1)
    foomod2 = mkmodule('foo', @modpath2)

    env = Puppet::Node::Environment.new
    env.modulepath = [@modpath1, @modpath2]

    Puppet::Face[:module, :current].list.should == {
      @modpath1 => [
        Puppet::Module.new('bar', :environment => env, :path => barmod1),
        Puppet::Module.new('foo', :environment => env, :path => foomod1)
      ],
      @modpath2 => [Puppet::Module.new('foo', :environment => env, :path => foomod2)]
    }
  end

  it "should use the specified environment" do
    foomod1 = mkmodule('foo', @modpath1)
    barmod1 = mkmodule('bar', @modpath1)

    usedenv = Puppet::Node::Environment.new('useme')
    usedenv.modulepath = [@modpath1, @modpath2]

    Puppet::Face[:module, :current].list(:env => 'useme').should == {
      @modpath1 => [
        Puppet::Module.new('bar', :environment => usedenv),
        Puppet::Module.new('foo', :environment => usedenv)
      ],
      @modpath2 => []
    }
  end

  it "should use the specified modulepath" do
    foomod1 = mkmodule('foo', @modpath1)
    barmod2 = mkmodule('bar', @modpath2)

    Puppet::Face[:module, :current].list(:modulepath => "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}").should == {
      @modpath1 => [ Puppet::Module.new('foo') ],
      @modpath2 => [ Puppet::Module.new('bar') ]
    }
  end

  it "should use the specified modulepath over the specified environment in place of the environment's default path" do
    foomod1 = mkmodule('foo', @modpath1)
    barmod2 = mkmodule('bar', @modpath2)
    env = Puppet::Node::Environment.new('myenv')
    env.modulepath = ['/tmp/notused']

    list = Puppet::Face[:module, :current].list(:env => 'myenv', :modulepath => "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}")

    # Changing Puppet[:modulepath] causes Puppet::Node::Environment.new('myenv')
    # to have a different object_id than the env above
    env = Puppet::Node::Environment.new('myenv')
    list.should == {
      @modpath1 => [ Puppet::Module.new('foo', :environment => env, :path => foomod1) ],
      @modpath2 => [ Puppet::Module.new('bar', :environment => env, :path => barmod2) ]
    }
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :list }

    its(:summary)     { should =~ /list.*module/im }
    its(:description) { should =~ /list.*module/im }
    its(:returns)     { should =~ /hash of paths to module objects/i }
    its(:examples)    { should_not be_empty }
  end

  describe "when rendering" do
  end
end
