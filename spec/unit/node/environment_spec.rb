#! /usr/bin/env ruby
require 'spec_helper'

require 'tmpdir'

require 'puppet/node/environment'
require 'puppet/util/execution'
require 'puppet_spec/modules'
require 'puppet/parser/parser_factory'

describe Puppet::Node::Environment do
  let(:env) { Puppet::Node::Environment.new("testing") }

  include PuppetSpec::Files
  after do
    Puppet::Node::Environment.clear
  end

  shared_examples_for 'the environment' do
    it "should use the filetimeout for the ttl for the module list" do
      Puppet::Node::Environment.attr_ttl(:modules).should == Integer(Puppet[:filetimeout])
    end

    it "should use the default environment if no name is provided while initializing an environment" do
      Puppet[:environment] = "one"
      Puppet::Node::Environment.new.name.should == :one
    end

    it "should treat environment instances as singletons" do
      Puppet::Node::Environment.new("one").should equal(Puppet::Node::Environment.new("one"))
    end

    it "should treat an environment specified as names or strings as equivalent" do
      Puppet::Node::Environment.new(:one).should equal(Puppet::Node::Environment.new("one"))
    end

    it "should return its name when converted to a string" do
      Puppet::Node::Environment.new(:one).to_s.should == "one"
    end

    it "should just return any provided environment if an environment is provided as the name" do
      one = Puppet::Node::Environment.new(:one)
      Puppet::Node::Environment.new(one).should equal(one)
    end

    describe "equality" do
      it "works as a hash key" do
        base = Puppet::Node::Environment.create(:first, ["modules"], "manifests")
        same = Puppet::Node::Environment.create(:first, ["modules"], "manifests")
        different = Puppet::Node::Environment.create(:first, ["different"], "manifests")
        hash = {}

        hash[base] = "base env"
        hash[same] = "same env"
        hash[different] = "different env"

        expect(hash[base]).to eq("same env")
        expect(hash[different]).to eq("different env")
        expect(hash).to have(2).item
      end

      it "is equal when name, modules, and manifests are the same" do
        base = Puppet::Node::Environment.create(:base, ["modules"], "manifests")
        different_name = Puppet::Node::Environment.create(:different, base.full_modulepath, base.manifest)

        expect(base).to_not eq("not an environment")

        expect(base).to eq(base)
        expect(base.hash).to eq(base.hash)

        expect(base.override_with(:modulepath => ["different"])).to_not eq(base)
        expect(base.override_with(:modulepath => ["different"]).hash).to_not eq(base.hash)

        expect(base.override_with(:manifest => "different")).to_not eq(base)
        expect(base.override_with(:manifest => "different").hash).to_not eq(base.hash)

        expect(different_name).to_not eq(base)
        expect(different_name.hash).to_not eq(base.hash)
      end
    end

    describe "overriding an existing environment" do
      let(:original_path) { [tmpdir('original')] }
      let(:new_path) { [tmpdir('new')] }
      let(:environment) { Puppet::Node::Environment.create(:overridden, original_path, 'orig.pp', '/config/script') }

      it "overrides modulepath" do
        overridden = environment.override_with(:modulepath => new_path)
        expect(overridden).to_not be_equal(environment)
        expect(overridden.name).to eq(:overridden)
        expect(overridden.manifest).to eq(File.expand_path('orig.pp'))
        expect(overridden.modulepath).to eq(new_path)
        expect(overridden.config_version).to eq('/config/script')
      end

      it "overrides manifest" do
        overridden = environment.override_with(:manifest => 'new.pp')
        expect(overridden).to_not be_equal(environment)
        expect(overridden.name).to eq(:overridden)
        expect(overridden.manifest).to eq(File.expand_path('new.pp'))
        expect(overridden.modulepath).to eq(original_path)
        expect(overridden.config_version).to eq('/config/script')
      end

      it "overrides config_version" do
        overridden = environment.override_with(:config_version => '/new/script')
        expect(overridden).to_not be_equal(environment)
        expect(overridden.name).to eq(:overridden)
        expect(overridden.manifest).to eq(File.expand_path('orig.pp'))
        expect(overridden.modulepath).to eq(original_path)
        expect(overridden.config_version).to eq('/new/script')
      end
    end

    describe "watching a file" do
      let(:filename) { "filename" }

      it "accepts a File" do
        file = tmpfile(filename)
        env.known_resource_types.expects(:watch_file).with(file.to_s)
        env.watch_file(file)
      end

      it "accepts a String" do
        env.known_resource_types.expects(:watch_file).with(filename)
        env.watch_file(filename)
      end
    end

    describe "when managing known resource types" do
      before do
        @collection = Puppet::Resource::TypeCollection.new(env)
        env.stubs(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
      end

      it "should create a resource type collection if none exists" do
        Puppet::Resource::TypeCollection.expects(:new).with(env).returns @collection
        env.known_resource_types.should equal(@collection)
      end

      it "should reuse any existing resource type collection" do
        env.known_resource_types.should equal(env.known_resource_types)
      end

      it "should perform the initial import when creating a new collection" do
        env.expects(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
        env.known_resource_types
      end

      it "should return the same collection even if stale if it's the same thread" do
        Puppet::Resource::TypeCollection.stubs(:new).returns @collection
        env.known_resource_types.stubs(:stale?).returns true

        env.known_resource_types.should equal(@collection)
      end

      it "should generate a new TypeCollection if the current one requires reparsing" do
        old_type_collection = env.known_resource_types
        old_type_collection.stubs(:require_reparse?).returns true

        env.check_for_reparse

        new_type_collection = env.known_resource_types
        new_type_collection.should be_a Puppet::Resource::TypeCollection
        new_type_collection.should_not equal(old_type_collection)
      end
    end

    it "should validate the modulepath directories" do
      real_file = tmpdir('moduledir')
      path = %W[/one /two #{real_file}].join(File::PATH_SEPARATOR)

      Puppet[:modulepath] = path

      env.modulepath.should == [real_file]
    end

    it "should prefix the value of the 'PUPPETLIB' environment variable to the module path if present" do
      first_puppetlib = tmpdir('puppetlib1')
      second_puppetlib = tmpdir('puppetlib2')
      first_moduledir = tmpdir('moduledir1')
      second_moduledir = tmpdir('moduledir2')
      Puppet::Util.withenv("PUPPETLIB" => [first_puppetlib, second_puppetlib].join(File::PATH_SEPARATOR)) do
        Puppet[:modulepath] = [first_moduledir, second_moduledir].join(File::PATH_SEPARATOR)

        env.modulepath.should == [first_puppetlib, second_puppetlib, first_moduledir, second_moduledir]
      end
    end

    it "does not register conflicting_manifest_settings? when not using directory environments" do
      expect(Puppet::Node::Environment.create(:directory, [], '/some/non/default/manifest.pp').conflicting_manifest_settings?).to be_false
    end

    describe "when operating in the context of directory environments" do
      before(:each) do
        Puppet[:environmentpath] = "$confdir/environments"
        Puppet[:default_manifest] = "/default/manifests/site.pp"
      end

      it "has no conflicting_manifest_settings? when disable_per_environment_manifest is false" do
        expect(Puppet::Node::Environment.create(:directory, [], '/some/non/default/manifest.pp').conflicting_manifest_settings?).to be_false
      end

      context "when disable_per_environment_manifest is true" do
        let(:config) { mock('config') }
        let(:global_modulepath) { ["/global/modulepath"] }
        let(:envconf) { Puppet::Settings::EnvironmentConf.new("/some/direnv", config, global_modulepath) }

        before(:each) do
          Puppet[:disable_per_environment_manifest] = true
        end

        def assert_manifest_conflict(expectation, envconf_manifest_value)
          config.expects(:setting).with(:manifest).returns(
            mock('setting', :value => envconf_manifest_value)
          )
          environment = Puppet::Node::Environment.create(:directory, [], '/default/manifests/site.pp')
          loader = Puppet::Environments::Static.new(environment)
          loader.stubs(:get_conf).returns(envconf)

          Puppet.override(:environments => loader) do
            expect(environment.conflicting_manifest_settings?).to eq(expectation)
          end
        end

        it "has conflicting_manifest_settings when environment.conf manifest was set" do
          assert_manifest_conflict(true, '/some/envconf/manifest/site.pp')
        end

        it "does not have conflicting_manifest_settings when environment.conf manifest is empty" do
          assert_manifest_conflict(false, '')
        end

        it "does not have conflicting_manifest_settings when environment.conf manifest is nil" do
          assert_manifest_conflict(false, nil)
        end

        it "does not have conflicting_manifest_settings when environment.conf manifest is an exact, uninterpolated match of default_manifest" do
          assert_manifest_conflict(false, '/default/manifests/site.pp')
        end
      end
    end

    describe "when modeling a specific environment" do
      it "should have a method for returning the environment name" do
        Puppet::Node::Environment.new("testing").name.should == :testing
      end

      it "should provide an array-like accessor method for returning any environment-specific setting" do
        env.should respond_to(:[])
      end

      it "obtains its core values from the puppet settings instance as a legacy env" do
        Puppet.settings.parse_config(<<-CONF)
        [testing]
        manifest = /some/manifest
        modulepath = /some/modulepath
        config_version = /some/script
        CONF

        env = Puppet::Node::Environment.new("testing")
        expect(env.full_modulepath).to eq([File.expand_path('/some/modulepath')])
        expect(env.manifest).to eq(File.expand_path('/some/manifest'))
        expect(env.config_version).to eq('/some/script')
      end

      it "should ask the Puppet settings instance for the setting qualified with the environment name" do
        Puppet.settings.parse_config(<<-CONF)
        [testing]
        server = myval
        CONF

        env[:server].should == "myval"
      end

      it "should be able to return an individual module that exists in its module path" do
        env.stubs(:modules).returns [Puppet::Module.new('one', "/one", mock("env"))]

        mod = env.module('one')
        mod.should be_a(Puppet::Module)
        mod.name.should == 'one'
      end

      it "should not return a module if the module doesn't exist" do
        env.stubs(:modules).returns [Puppet::Module.new('one', "/one", mock("env"))]

        env.module('two').should be_nil
      end

      it "should return nil if asked for a module that does not exist in its path" do
        modpath = tmpdir('modpath')
        env = Puppet::Node::Environment.create(:testing, [modpath])

        env.module("one").should be_nil
      end

      describe "module data" do
        before do
          dir = tmpdir("deep_path")

          @first = File.join(dir, "first")
          @second = File.join(dir, "second")
          Puppet[:modulepath] = "#{@first}#{File::PATH_SEPARATOR}#{@second}"

          FileUtils.mkdir_p(@first)
          FileUtils.mkdir_p(@second)
        end

        describe "#modules_by_path" do
          it "should return an empty list if there are no modules" do
            env.modules_by_path.should == {
              @first  => [],
              @second => []
            }
          end

          it "should include modules even if they exist in multiple dirs in the modulepath" do
            modpath1 = File.join(@first, "foo")
            FileUtils.mkdir_p(modpath1)
            modpath2 = File.join(@second, "foo")
            FileUtils.mkdir_p(modpath2)

            env.modules_by_path.should == {
              @first  => [Puppet::Module.new('foo', modpath1, env)],
              @second => [Puppet::Module.new('foo', modpath2, env)]
            }
          end

          it "should ignore modules with invalid names" do
            FileUtils.mkdir_p(File.join(@first, 'foo'))
            FileUtils.mkdir_p(File.join(@first, 'foo2'))
            FileUtils.mkdir_p(File.join(@first, 'foo-bar'))
            FileUtils.mkdir_p(File.join(@first, 'foo_bar'))
            FileUtils.mkdir_p(File.join(@first, 'foo=bar'))
            FileUtils.mkdir_p(File.join(@first, 'foo bar'))
            FileUtils.mkdir_p(File.join(@first, 'foo.bar'))
            FileUtils.mkdir_p(File.join(@first, '-foo'))
            FileUtils.mkdir_p(File.join(@first, 'foo-'))
            FileUtils.mkdir_p(File.join(@first, 'foo--bar'))

            env.modules_by_path[@first].collect{|mod| mod.name}.sort.should == %w{foo foo-bar foo2 foo_bar}
          end

        end

        describe "#module_requirements" do
          it "should return a list of what modules depend on other modules" do
            PuppetSpec::Modules.create(
              'foo',
              @first,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs/bar', "version_requirement" => ">= 1.0.0" }]
              }
            )
            PuppetSpec::Modules.create(
              'bar',
              @second,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs/foo', "version_requirement" => "<= 2.0.0" }]
              }
            )
            PuppetSpec::Modules.create(
              'baz',
              @first,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs-bar', "version_requirement" => "3.0.0" }]
              }
            )
            PuppetSpec::Modules.create(
              'alpha',
              @first,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs/bar', "version_requirement" => "~3.0.0" }]
              }
            )

            env.module_requirements.should == {
              'puppetlabs/alpha' => [],
              'puppetlabs/foo' => [
                {
                  "name"    => "puppetlabs/bar",
                  "version" => "9.9.9",
                  "version_requirement" => "<= 2.0.0"
                }
              ],
              'puppetlabs/bar' => [
                {
                  "name"    => "puppetlabs/alpha",
                  "version" => "9.9.9",
                  "version_requirement" => "~3.0.0"
                },
                {
                  "name"    => "puppetlabs/baz",
                  "version" => "9.9.9",
                  "version_requirement" => "3.0.0"
                },
                {
                  "name"    => "puppetlabs/foo",
                  "version" => "9.9.9",
                  "version_requirement" => ">= 1.0.0"
                }
              ],
              'puppetlabs/baz' => []
            }
          end
        end

        describe ".module_by_forge_name" do
          it "should find modules by forge_name" do
            mod = PuppetSpec::Modules.create(
              'baz',
              @first,
              :metadata => {:author => 'puppetlabs'},
              :environment => env
            )
            env.module_by_forge_name('puppetlabs/baz').should == mod
          end

          it "should not find modules with same name by the wrong author" do
            mod = PuppetSpec::Modules.create(
              'baz',
              @first,
              :metadata => {:author => 'sneakylabs'},
              :environment => env
            )
            env.module_by_forge_name('puppetlabs/baz').should == nil
          end

          it "should return nil when the module can't be found" do
            env.module_by_forge_name('ima/nothere').should be_nil
          end
        end

        describe ".modules" do
          it "should return an empty list if there are no modules" do
            env.modules.should == []
          end

          it "should return a module named for every directory in each module path" do
            %w{foo bar}.each do |mod_name|
              FileUtils.mkdir_p(File.join(@first, mod_name))
            end
            %w{bee baz}.each do |mod_name|
              FileUtils.mkdir_p(File.join(@second, mod_name))
            end
            env.modules.collect{|mod| mod.name}.sort.should == %w{foo bar bee baz}.sort
          end

          it "should remove duplicates" do
            FileUtils.mkdir_p(File.join(@first,  'foo'))
            FileUtils.mkdir_p(File.join(@second, 'foo'))

            env.modules.collect{|mod| mod.name}.sort.should == %w{foo}
          end

          it "should ignore modules with invalid names" do
            FileUtils.mkdir_p(File.join(@first, 'foo'))
            FileUtils.mkdir_p(File.join(@first, 'foo2'))
            FileUtils.mkdir_p(File.join(@first, 'foo-bar'))
            FileUtils.mkdir_p(File.join(@first, 'foo_bar'))
            FileUtils.mkdir_p(File.join(@first, 'foo=bar'))
            FileUtils.mkdir_p(File.join(@first, 'foo bar'))

            env.modules.collect{|mod| mod.name}.sort.should == %w{foo foo-bar foo2 foo_bar}
          end

          it "should create modules with the correct environment" do
            FileUtils.mkdir_p(File.join(@first, 'foo'))
            env.modules.each {|mod| mod.environment.should == env }
          end

        end
      end
    end

    describe "when performing initial import" do
      def parser_and_environment(name)
        env = Puppet::Node::Environment.new(name)
        parser = Puppet::Parser::ParserFactory.parser(env)
        Puppet::Parser::ParserFactory.stubs(:parser).returns(parser)

        [parser, env]
      end

      it "should set the parser's string to the 'code' setting and parse if code is available" do
        Puppet[:code] = "my code"
        parser, env = parser_and_environment('testing')

        parser.expects(:string=).with "my code"
        parser.expects(:parse)

        env.instance_eval { perform_initial_import }
      end

      it "should set the parser's file to the 'manifest' setting and parse if no code is available and the manifest is available" do
        filename = tmpfile('myfile')
        Puppet[:manifest] = filename
        parser, env = parser_and_environment('testing')

        parser.expects(:file=).with filename
        parser.expects(:parse)

        env.instance_eval { perform_initial_import }
      end

      it "should pass the manifest file to the parser even if it does not exist on disk" do
        filename = tmpfile('myfile')
        Puppet[:code] = ""
        Puppet[:manifest] = filename
        parser, env = parser_and_environment('testing')

        parser.expects(:file=).with(filename).once
        parser.expects(:parse).once

        env.instance_eval { perform_initial_import }
      end

      it "should fail helpfully if there is an error importing" do
        Puppet::FileSystem.stubs(:exist?).returns true
        parser, env = parser_and_environment('testing')

        parser.expects(:file=).once
        parser.expects(:parse).raises ArgumentError

        expect do
          env.known_resource_types
        end.to raise_error(Puppet::Error)
      end

      it "should not do anything if the ignore_import settings is set" do
        Puppet[:ignoreimport] = true
        parser, env = parser_and_environment('testing')

        parser.expects(:string=).never
        parser.expects(:file=).never
        parser.expects(:parse).never

        env.instance_eval { perform_initial_import }
      end

      it "should mark the type collection as needing a reparse when there is an error parsing" do
        parser, env = parser_and_environment('testing')

        parser.expects(:parse).raises Puppet::ParseError.new("Syntax error at ...")

        expect do
          env.known_resource_types
        end.to raise_error(Puppet::Error, /Syntax error at .../)
        env.known_resource_types.require_reparse?.should be_true
      end
    end
  end

  describe 'with classic parser' do
    before :each do
      Puppet[:parser] = 'current'
    end
    it_behaves_like 'the environment'
  end

  describe 'with future parser' do
    before :each do
      Puppet[:parser] = 'future'
    end
    it_behaves_like 'the environment'
  end

  describe '#current' do
    it 'should return the current context' do
      env = Puppet::Node::Environment.new(:test)
      Puppet::Context.any_instance.expects(:lookup).with(:current_environment).returns(env)
      Puppet.expects(:deprecation_warning).once
      Puppet::Node::Environment.current.should equal(env)
    end
  end

end
