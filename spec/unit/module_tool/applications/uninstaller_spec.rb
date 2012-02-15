require 'spec_helper'
require 'puppet/module_tool'
require 'tmpdir'
require 'puppet_spec/modules'

describe Puppet::Module::Tool::Applications::Uninstaller do
  include PuppetSpec::Files

  def mkmod(name, path, metadata=nil)
    modpath = File.join(path, name)
    FileUtils.mkdir_p(modpath)

    if metadata
      File.open(File.join(modpath, 'metadata.json'), 'w') do |f|
        f.write(metadata.to_pson)
      end
    end

    modpath
  end

  describe "the behavior of the instances" do

    before do
      @uninstaller = Puppet::Module::Tool::Applications::Uninstaller
      FileUtils.mkdir_p(modpath1)
      FileUtils.mkdir_p(modpath2)
      fake_env.modulepath = [modpath1, modpath2]
    end

    let(:modpath1) { File.join(tmpdir("uninstaller"), "modpath1") }
    let(:modpath2) { File.join(tmpdir("uninstaller"), "modpath2") }
    let(:fake_env) { Puppet::Node::Environment.new('fake_env') }
    let(:options)  { {:environment => "fake_env"} }

    let(:foo_metadata) do
      {
        "author"       => "puppetlabs",
        "name"         => "puppetlabs/foo",
        "version"      => "1.0.0",
        "source"       => "http://dummyurl/foo",
        "license"      => "Apache2",
        "dependencies" => [],
      }
    end

    let(:bar_metadata) do
      {
        "author"       => "puppetlabs",
        "name"         => "puppetlabs/bar",
        "version"      => "1.0.0",
        "source"       => "http://dummyurl/bar",
        "license"      => "Apache2",
        "dependencies" => [],
      }
    end

    context "when the module is not installed" do
      it "should return an empty list" do
        results = @uninstaller.new('fakemod_not_installed', options).run
        results[:removed_mods].should == []
      end
    end

    context "when the module is installed" do

      it "should uninstall the module" do
        PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

        results = @uninstaller.new("puppetlabs-foo", options).run
        results[:removed_mods].first.forge_name.should == "puppetlabs/foo"
      end

      it "should only uninstall the requested module" do
        PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)
        PuppetSpec::Modules.create('bar', modpath1, :metadata => bar_metadata)

        results = @uninstaller.new("puppetlabs-foo", options).run
        results[:removed_mods].length == 1
        results[:removed_mods].first.forge_name.should == "puppetlabs/foo"
      end

      it "should uninstall the module from every path in the modpath" do
        PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)
        PuppetSpec::Modules.create('foo', modpath2, :metadata => foo_metadata)

        results = @uninstaller.new('puppetlabs-foo', options).run
        results[:removed_mods].length.should == 2
        results[:removed_mods][0].forge_name.should == "puppetlabs/foo"
        results[:removed_mods][1].forge_name.should == "puppetlabs/foo"
      end

      context "when options[:version] is specified" do

        it "should uninstall the module if the version matches" do
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          options[:version] = "1.0.0"

          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].length.should == 1
          results[:removed_mods].first.forge_name.should == "puppetlabs/foo"
          results[:removed_mods].first.version.should == "1.0.0"
        end

        it "should not uninstall the module if the version does not match" do
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          options[:version] = "2.0.0"

          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].should == []
        end
      end

      context "when the module metadata is missing" do

        it "should not uninstall the module" do
          PuppetSpec::Modules.create('foo', modpath1)

          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].should == []
        end
      end

      context "when the module has local changes" do

        it "should not uninstall the module" do
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)
          Puppet::Module.any_instance.stubs(:has_local_changes?).returns(true)
          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].should == []
        end

      end

      context "when the module does not have local changes" do

        it "should uninstall the module" do
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].length.should == 1
          results[:removed_mods].first.forge_name.should == "puppetlabs/foo"
        end
      end

      context "when uninstalling the module will cause broken dependencies" do
        it "should not uninstall the module" do
          Puppet.settings[:modulepath] = modpath1
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          PuppetSpec::Modules.create(
            'needy',
            modpath1,
            :metadata => {
              :author => 'beggar',
              :dependencies => [{
                  "version_requirement" => ">= 1.0.0",
                  "name" => "puppetlabs/foo"
              }]
            }
          )

          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].should be_empty
        end
      end

      context "when using the --force flag" do

        let(:fakemod) do
          stub(
            :forge_name => 'puppetlabs/fakemod',
            :version    => '0.0.1',
            :has_local_changes? => true
          )
        end

        it "should ignore local changes" do
          foo = mkmod("foo", modpath1, foo_metadata)
          options[:force] = true

          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].length.should == 1
          results[:removed_mods].first.forge_name.should == "puppetlabs/foo"
        end

        it "should ignore broken dependencies" do
          Puppet.settings[:modulepath] = modpath1
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          PuppetSpec::Modules.create(
            'needy',
            modpath1,
            :metadata => {
              :author => 'beggar',
              :dependencies => [{
                  "version_requirement" => ">= 1.0.0",
                  "name" => "puppetlabs/foo"
              }]
            }
          )
          options[:force] = true

          results = @uninstaller.new("puppetlabs-foo", options).run
          results[:removed_mods].length.should == 1
          results[:removed_mods].first.forge_name.should == "puppetlabs/foo"
        end
      end
    end
  end
end
