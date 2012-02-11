require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'
require 'puppet_spec/modules'

describe "puppet module list" do
  include PuppetSpec::Files

  before do
    dir = tmpdir("deep_path")

    @modpath1 = File.join(dir, "modpath1")
    @modpath2 = File.join(dir, "modpath2")
    @modulepath = "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}"
    Puppet.settings[:modulepath] = @modulepath

    FileUtils.mkdir_p(@modpath1)
    FileUtils.mkdir_p(@modpath2)
  end

  it "should return an empty list per dir in path if there are no modules" do
    Puppet.settings[:modulepath] = @modulepath
    Puppet::Face[:module, :current].list.should == {
      @modpath1 => [],
      @modpath2 => []
    }
  end

  it "should include modules separated by the environment's modulepath" do
    foomod1 = PuppetSpec::Modules.create('foo', @modpath1)
    barmod1 = PuppetSpec::Modules.create('bar', @modpath1)
    foomod2 = PuppetSpec::Modules.create('foo', @modpath2)

    env = Puppet::Node::Environment.new

    Puppet::Face[:module, :current].list.should == {
      @modpath1 => [
        Puppet::Module.new('bar', :environment => env, :path => barmod1),
        Puppet::Module.new('foo', :environment => env, :path => foomod1)
      ],
      @modpath2 => [Puppet::Module.new('foo', :environment => env, :path => foomod2)]
    }
  end

  it "should use the specified environment" do
    foomod1 = PuppetSpec::Modules.create('foo', @modpath1)
    barmod1 = PuppetSpec::Modules.create('bar', @modpath1)

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
    foomod1 = PuppetSpec::Modules.create('foo', @modpath1)
    barmod2 = PuppetSpec::Modules.create('bar', @modpath2)

    Puppet::Face[:module, :current].list(:modulepath => "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}").should == {
      @modpath1 => [ Puppet::Module.new('foo') ],
      @modpath2 => [ Puppet::Module.new('bar') ]
    }
  end

  it "should use the specified modulepath over the specified environment in place of the environment's default path" do
    foomod1 = PuppetSpec::Modules.create('foo', @modpath1)
    barmod2 = PuppetSpec::Modules.create('bar', @modpath2)
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
    it "should explicitly state when a modulepath is empty" do
      empty_modpath = tmpdir('empty')
      Puppet::Face[:module, :current].list_when_rendering_console(
        { empty_modpath => [] },
        {:modulepath => empty_modpath}
      ).should == <<-HEREDOC.gsub('        ', '')
        #{empty_modpath} (No modules installed)
      HEREDOC
    end

    it "should print dependencies as a tree" do
      PuppetSpec::Modules.create('dependable', @modpath1, :version => '0.0.5')
      PuppetSpec::Modules.create(
        'other_mod',
        @modpath1,
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 0.0.5",
          "name"                => "matt/dependable"
        }]
      )

      dependency_tree = Puppet::Face[:module, :current].list

      output = Puppet::Face[:module, :current].list_when_rendering_console(
        dependency_tree,
        {:tree => true}
      )

      output.should == <<-HEREDOC.gsub('        ', '')
        #{@modpath1}
        other_mod (1.0.0)
          dependable (0.0.5)
        #{@modpath2} (No modules installed)
      HEREDOC
    end
  end
end
