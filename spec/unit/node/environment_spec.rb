#! /usr/bin/env ruby
require 'spec_helper'

require 'tmpdir'

require 'puppet/node/environment'
require 'puppet/util/execution'
require 'puppet_spec/modules'
require 'puppet/parser/parser_factory'

describe Puppet::Node::Environment do
  let(:env) { Puppet::Node::Environment.create("testing", []) }

  include PuppetSpec::Files

  context 'the environment' do
    it "converts an environment to string when converting to YAML" do
      expect(env.to_yaml).to match(/--- testing/)
    end

    describe ".create" do
      it "creates equivalent environments whether specifying name as a symbol or a string" do
        expect(Puppet::Node::Environment.create(:one, [])).to eq(Puppet::Node::Environment.create("one", []))
      end

      it "interns name" do
        expect(Puppet::Node::Environment.create("one", []).name).to equal(:one)
      end
      it "does not produce environment singletons" do
        expect(Puppet::Node::Environment.create("one", [])).to_not equal(Puppet::Node::Environment.create("one", []))
      end
    end

    it "returns its name when converted to a string" do
      expect(env.to_s).to eq("testing")
    end

    it "has an inspect method for debugging" do
      e = Puppet::Node::Environment.create(:test, ['/modules/path', '/other/modules'], '/manifests/path')
      expect("a #{e} env").to eq("a test env")
      expect(e.inspect).to match(%r{<Puppet::Node::Environment:\w* @name="test" @manifest="#{File.expand_path('/manifests/path')}" @modulepath="#{File.expand_path('/modules/path')}:#{File.expand_path('/other/modules')}" >})
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

    describe "when managing known resource types" do
      before do
        env.stubs(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
      end

      it "creates a resource type collection if none exists" do
        expect(env.known_resource_types).to be_kind_of(Puppet::Resource::TypeCollection)
      end

      it "memoizes resource type collection" do
        expect(env.known_resource_types).to equal(env.known_resource_types)
      end

      it "performs the initial import when creating a new collection" do
        env.expects(:perform_initial_import).returns(Puppet::Parser::AST::Hostclass.new(''))
        env.known_resource_types
      end

      it "generates a new TypeCollection if the current one requires reparsing" do
        old_type_collection = env.known_resource_types
        old_type_collection.stubs(:parse_failed?).returns true

        env.check_for_reparse

        new_type_collection = env.known_resource_types
        expect(new_type_collection).to be_a Puppet::Resource::TypeCollection
        expect(new_type_collection).to_not equal(old_type_collection)
      end
    end

    it "validates the modulepath directories" do
      real_file = tmpdir('moduledir')
      path = ['/one', '/two', real_file]

      env = Puppet::Node::Environment.create(:test, path)

      expect(env.modulepath).to eq([real_file])
    end

    it "prefixes the value of the 'PUPPETLIB' environment variable to the module path if present" do
      first_puppetlib = tmpdir('puppetlib1')
      second_puppetlib = tmpdir('puppetlib2')
      first_moduledir = tmpdir('moduledir1')
      second_moduledir = tmpdir('moduledir2')
      Puppet::Util.withenv("PUPPETLIB" => [first_puppetlib, second_puppetlib].join(File::PATH_SEPARATOR)) do
        env = Puppet::Node::Environment.create(:testing, [first_moduledir, second_moduledir])

        expect(env.modulepath).to eq([first_puppetlib, second_puppetlib, first_moduledir, second_moduledir])
      end
    end

    describe "validating manifest settings" do
      before(:each) do
        Puppet[:default_manifest] = "/default/manifests/site.pp"
      end

      it "has no validation errors when disable_per_environment_manifest is false" do
        expect(Puppet::Node::Environment.create(:directory, [], '/some/non/default/manifest.pp').validation_errors).to be_empty
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
            if expectation
              expect(environment.validation_errors).to have_matching_element(/The 'disable_per_environment_manifest' setting is true.*and the.*environment.*conflicts/)
            else
              expect(environment.validation_errors).to be_empty
            end
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
      let(:first_modulepath) { tmpdir('firstmodules') }
      let(:second_modulepath) { tmpdir('secondmodules') }
      let(:env) { Puppet::Node::Environment.create(:modules_test, [first_modulepath, second_modulepath]) }
      let(:module_options) {
        {
          :environment => env,
          :metadata => {
            :author       => 'puppetlabs',
          },
        }
      }

      describe "module data" do
        describe ".module" do

          it "returns an individual module that exists in its module path" do
            one = PuppetSpec::Modules.create('one', first_modulepath, module_options)
            expect(env.module('one')).to eq(one)
          end

          it "returns nil if asked for a module that does not exist in its path" do
            expect(env.module("doesnotexist")).to be_nil
          end
        end

        describe "#modules_by_path" do
          it "returns an empty list if there are no modules" do
            expect(env.modules_by_path).to eq({
              first_modulepath => [],
              second_modulepath => []
            })
          end

          it "includes modules even if they exist in multiple dirs in the modulepath" do
            one = PuppetSpec::Modules.create('one', first_modulepath, module_options)
            two = PuppetSpec::Modules.create('two', second_modulepath, module_options)

            expect(env.modules_by_path).to eq({
              first_modulepath  => [one],
              second_modulepath => [two],
            })
          end

          it "ignores modules with invalid names" do
            PuppetSpec::Modules.generate_files('foo', first_modulepath)
            PuppetSpec::Modules.generate_files('.foo', first_modulepath)
            PuppetSpec::Modules.generate_files('foo2', first_modulepath)
            PuppetSpec::Modules.generate_files('foo-bar', first_modulepath)
            PuppetSpec::Modules.generate_files('foo_bar', first_modulepath)
            PuppetSpec::Modules.generate_files('foo=bar', first_modulepath)
            PuppetSpec::Modules.generate_files('foo bar', first_modulepath)
            PuppetSpec::Modules.generate_files('foo.bar', first_modulepath)
            PuppetSpec::Modules.generate_files('-foo', first_modulepath)
            PuppetSpec::Modules.generate_files('foo-', first_modulepath)
            PuppetSpec::Modules.generate_files('foo--bar', first_modulepath)

            expect(env.modules_by_path[first_modulepath].collect{|mod| mod.name}.sort).to eq(%w{foo foo2 foo_bar})
          end

        end

        describe "#module_requirements" do
          it "returns a list of what modules depend on other modules" do
            PuppetSpec::Modules.create(
              'foo',
              first_modulepath,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs/bar', "version_requirement" => ">= 1.0.0" }]
              }
            )
            PuppetSpec::Modules.create(
              'bar',
              second_modulepath,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs/foo', "version_requirement" => "<= 2.0.0" }]
              }
            )
            PuppetSpec::Modules.create(
              'baz',
              first_modulepath,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs-bar', "version_requirement" => "3.0.0" }]
              }
            )
            PuppetSpec::Modules.create(
              'alpha',
              first_modulepath,
              :metadata => {
                :author       => 'puppetlabs',
                :dependencies => [{ 'name' => 'puppetlabs/bar', "version_requirement" => "~3.0.0" }]
              }
            )

            expect(env.module_requirements).to eq({
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
            })
          end
        end

        describe ".module_by_forge_name" do
          it "finds modules by forge_name" do
            mod = PuppetSpec::Modules.create(
              'baz',
              first_modulepath,
              module_options
            )
            expect(env.module_by_forge_name('puppetlabs/baz')).to eq(mod)
          end

          it "does not find modules with same name by the wrong author" do
            mod = PuppetSpec::Modules.create(
              'baz',
              first_modulepath,
              :metadata => {:author => 'sneakylabs'},
              :environment => env
            )
            expect(env.module_by_forge_name('puppetlabs/baz')).to eq(nil)
          end

          it "returns nil when the module can't be found" do
            expect(env.module_by_forge_name('ima/nothere')).to be_nil
          end
        end

        describe ".modules" do
          it "returns an empty list if there are no modules" do
            expect(env.modules).to eq([])
          end

          it "returns a module named for every directory in each module path" do
            %w{foo bar}.each do |mod_name|
              PuppetSpec::Modules.generate_files(mod_name, first_modulepath)
            end
            %w{bee baz}.each do |mod_name|
              PuppetSpec::Modules.generate_files(mod_name, second_modulepath)
            end
            expect(env.modules.collect{|mod| mod.name}.sort).to eq(%w{foo bar bee baz}.sort)
          end

          it "removes duplicates" do
            PuppetSpec::Modules.generate_files('foo', first_modulepath)
            PuppetSpec::Modules.generate_files('foo', second_modulepath)

            expect(env.modules.collect{|mod| mod.name}.sort).to eq(%w{foo})
          end

          it "ignores modules with invalid names" do
            PuppetSpec::Modules.generate_files('foo', first_modulepath)
            PuppetSpec::Modules.generate_files('.foo', first_modulepath)
            PuppetSpec::Modules.generate_files('foo2', first_modulepath)
            PuppetSpec::Modules.generate_files('foo-bar', first_modulepath)
            PuppetSpec::Modules.generate_files('foo_bar', first_modulepath)
            PuppetSpec::Modules.generate_files('foo=bar', first_modulepath)
            PuppetSpec::Modules.generate_files('foo bar', first_modulepath)

            expect(env.modules.collect{|mod| mod.name}.sort).to eq(%w{foo foo2 foo_bar})
          end

          it "creates modules with the correct environment" do
            PuppetSpec::Modules.generate_files('foo', first_modulepath)

            env.modules.each do |mod| 
              expect(mod.environment).to eq(env)
            end
          end

          it "logs an exception if a module contains invalid metadata" do
            PuppetSpec::Modules.generate_files(
              'foo',
              first_modulepath,
              :metadata => {
                :author       => 'puppetlabs'
                # missing source, version, etc
              }
            )

            Puppet.expects(:log_exception).with(is_a(Puppet::Module::MissingMetadata))

            env.modules
          end
        end
      end
    end

    describe "when performing initial import" do
      let(:loaders) { Puppet::Pops::Loaders.new(env) }

      around :each do |example|
        Puppet::Parser::Compiler.any_instance.stubs(:loaders).returns(loaders)
        Puppet.override(:loaders => loaders, :current_environment => env) do
          example.run
          Puppet::Pops::Loaders.clear
        end
      end

      it "loads from Puppet[:code]" do
        Puppet[:code] = "define foo {}"
        krt = env.known_resource_types
        expect(krt.find_definition('foo')).to be_kind_of(Puppet::Resource::Type)
      end

      it "parses from the the environment's manifests if Puppet[:code] is not set" do
        filename = tmpfile('a_manifest.pp')
        File.open(filename, 'w') do |f|
          f.puts("define from_manifest {}")
        end
        env = Puppet::Node::Environment.create(:testing, [], filename)
        krt = env.known_resource_types
        expect(krt.find_definition('from_manifest')).to be_kind_of(Puppet::Resource::Type)
      end

      it "prefers Puppet[:code] over manifest files" do
        Puppet[:code] = "define from_code_setting {}"
        filename = tmpfile('a_manifest.pp')
        File.open(filename, 'w') do |f|
          f.puts("define from_manifest {}")
        end
        env = Puppet::Node::Environment.create(:testing, [], filename)
        krt = env.known_resource_types
        expect(krt.find_definition('from_code_setting')).to be_kind_of(Puppet::Resource::Type)
      end

      it "initial import proceeds even if manifest file does not exist on disk" do
        filename = tmpfile('a_manifest.pp')
        env = Puppet::Node::Environment.create(:testing, [], filename)
        expect(env.known_resource_types).to be_kind_of(Puppet::Resource::TypeCollection)
      end

      it "returns an empty TypeCollection if neither code nor manifests is present" do
        expect(env.known_resource_types).to be_kind_of(Puppet::Resource::TypeCollection)
      end

      it "fails helpfully if there is an error importing" do
        Puppet[:code] = "oops {"
        expect do
          env.known_resource_types
        end.to raise_error(Puppet::Error, /Could not parse for environment #{env.name}/)
      end

      it "should mark the type collection as needing a reparse when there is an error parsing" do
        Puppet[:code] = "oops {"
        expect do
          env.known_resource_types
        end.to raise_error(Puppet::Error, /Syntax error at .../)
        expect(env.known_resource_types.parse_failed?).to be_truthy
      end
    end
  end

end
