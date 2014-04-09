require 'spec_helper'
require 'puppet/module_tool'
require 'tmpdir'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Uninstaller do
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
    let(:working_dir) { tmpdir("uninstaller") }
    let(:modpath1) { create_temp_dir("modpath1") }
    let(:modpath2) { create_temp_dir("modpath2") }
    let(:env) { Puppet::Node::Environment.create(:env, [modpath1, modpath2]) }
    let(:options)  { { :environment_instance => env } }
    let(:uninstaller) { Puppet::ModuleTool::Applications::Uninstaller.new("puppetlabs-foo", options) }

    def create_temp_dir(name)
      path = File.join(working_dir, name)
      FileUtils.mkdir_p(path)
      path
    end

    let(:foo_metadata) do
      {
        :author       => "puppetlabs",
        :name         => "puppetlabs/foo",
        :version      => "1.0.0",
        :source       => "http://dummyurl/foo",
        :license      => "Apache2",
        :dependencies => [],
      }
    end

    let(:bar_metadata) do
      {
        :author       => "puppetlabs",
        :name         => "puppetlabs/bar",
        :version      => "1.0.0",
        :source       => "http://dummyurl/bar",
        :license      => "Apache2",
        :dependencies => [],
      }
    end

    context "when the module is not installed" do
      it "should fail" do
        Puppet::ModuleTool::Applications::Uninstaller.new('fakemod_not_installed', options).run[:result].should == :failure
      end
    end

    context "when the module is installed" do

      it "should uninstall the module" do
        PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

        results = uninstaller.run

        results[:affected_modules].first.forge_name.should == "puppetlabs/foo"
      end

      it "should only uninstall the requested module" do
        PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)
        PuppetSpec::Modules.create('bar', modpath1, :metadata => bar_metadata)

        results = uninstaller.run
        results[:affected_modules].length == 1
        results[:affected_modules].first.forge_name.should == "puppetlabs/foo"
      end

      it "should uninstall fail if a module exists twice in the modpath" do
        PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)
        PuppetSpec::Modules.create('foo', modpath2, :metadata => foo_metadata)

        uninstaller.run[:result].should == :failure
      end

      context "when options[:version] is specified" do

        it "should uninstall the module if the version matches" do
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          options[:version] = "1.0.0"

          results = uninstaller.run
          results[:affected_modules].length.should == 1
          results[:affected_modules].first.forge_name.should == "puppetlabs/foo"
          results[:affected_modules].first.version.should == "1.0.0"
        end

        it "should not uninstall the module if the version does not match" do
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          options[:version] = "2.0.0"

          uninstaller.run[:result].should == :failure
        end
      end

      context "when the module metadata is missing" do

        it "should not uninstall the module" do
          PuppetSpec::Modules.create('foo', modpath1)

          uninstaller.run[:result].should == :failure
        end
      end

      context "when the module has local changes" do

        it "should not uninstall the module" do
          mod = PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)
          Puppet::ModuleTool::Applications::Checksummer.expects(:run).with(mod.path).returns(['change'])

          uninstaller.run[:result].should == :failure
        end

      end

      context "when the module does not have local changes" do

        it "should uninstall the module" do
          PuppetSpec::Modules.create('foo', modpath1, :metadata => foo_metadata)

          results = uninstaller.run
          results[:affected_modules].length.should == 1
          results[:affected_modules].first.forge_name.should == "puppetlabs/foo"
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

          uninstaller.run[:result].should == :failure
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

          results = uninstaller.run
          results[:affected_modules].length.should == 1
          results[:affected_modules].first.forge_name.should == "puppetlabs/foo"
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

          results = uninstaller.run
          results[:affected_modules].length.should == 1
          results[:affected_modules].first.forge_name.should == "puppetlabs/foo"
        end
      end
    end
  end
end
