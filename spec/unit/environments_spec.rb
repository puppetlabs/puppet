require 'spec_helper'
require 'puppet/environments'
require 'puppet/file_system'
require 'matchers/include'
require 'matchers/include_in_order'

module PuppetEnvironments
describe Puppet::Environments do
  include Matchers::Include

  FS = Puppet::FileSystem

  before(:each) do
    Puppet.settings.initialize_global_settings
    Puppet[:environment_timeout] = "unlimited"
  end

  let(:directory_tree) do
    FS::MemoryFile.a_directory(File.expand_path("envdir"), [
      FS::MemoryFile.a_regular_file_containing("ignored_file", ''),
      FS::MemoryFile.a_directory("an_environment", [
        FS::MemoryFile.a_missing_file("environment.conf"),
        FS::MemoryFile.a_directory("modules"),
        FS::MemoryFile.a_directory("manifests"),
      ]),
      FS::MemoryFile.a_directory("another_environment", [
        FS::MemoryFile.a_missing_file("environment.conf"),
      ]),
      FS::MemoryFile.a_missing_file("doesnotexist"),
    ])
  end

  describe "directories loader" do
    it "lists environments" do
      global_path_1_location = File.expand_path("global_path_1")
      global_path_2_location = File.expand_path("global_path_2")
      global_path_1 = FS::MemoryFile.a_directory(global_path_1_location)
      global_path_2 = FS::MemoryFile.a_directory(global_path_2_location)

      loader_from(:filesystem => [directory_tree, global_path_1, global_path_2],
                  :directory => directory_tree,
                  :modulepath => [global_path_1_location, global_path_2_location]) do |loader|
        expect(loader.list).to include_in_any_order(
          environment(:an_environment).
            with_manifest("#{FS.path_string(directory_tree)}/an_environment/manifests").
            with_modulepath(["#{FS.path_string(directory_tree)}/an_environment/modules",
                             global_path_1_location,
                             global_path_2_location]),
          environment(:another_environment))
      end
    end

    it "has search_paths" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect(loader.search_paths).to eq(["file://#{directory_tree}"])
      end
    end

    it "ignores directories that are not valid env names (alphanumeric and _)" do
      envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
        FS::MemoryFile.a_directory(".foo"),
        FS::MemoryFile.a_directory("bar-thing"),
        FS::MemoryFile.a_directory("with spaces"),
        FS::MemoryFile.a_directory("some.thing"),
        FS::MemoryFile.a_directory("env1", [
          FS::MemoryFile.a_missing_file("environment.conf"),
        ]),
        FS::MemoryFile.a_directory("env2", [
          FS::MemoryFile.a_missing_file("environment.conf"),
        ]),
      ])

      loader_from(:filesystem => [envdir],
                  :directory => envdir) do |loader|
        expect(loader.list).to include_in_any_order(environment(:env1), environment(:env2))
      end
    end

    it "gets a particular environment" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect(loader.get("an_environment")).to environment(:an_environment)
      end
    end

    it "raises error when environment not found" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect do
          loader.get!("doesnotexist")
        end.to raise_error(Puppet::Environments::EnvironmentNotFound)
      end
    end

    it "returns nil if an environment can't be found" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect(loader.get("doesnotexist")).to be_nil
      end
    end

    context "with an environment.conf" do
      let(:envdir) do
        FS::MemoryFile.a_directory(File.expand_path("envdir"), [
          FS::MemoryFile.a_directory("env1", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", content),
          ]),
        ])
      end
      let(:manifestdir) { FS::MemoryFile.a_directory(File.expand_path("/some/manifest/path")) }
      let(:modulepath) do
        [
          FS::MemoryFile.a_directory(File.expand_path("/some/module/path")),
          FS::MemoryFile.a_directory(File.expand_path("/some/other/path")),
        ]
      end

      let(:content) do
        <<-EOF
manifest=#{manifestdir}
modulepath=#{modulepath.join(File::PATH_SEPARATOR)}
config_version=/some/script
static_catalogs=false
        EOF
      end

      it "reads environment.conf settings" do
        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path))
        end
      end

      it "does not append global_module_path to environment.conf modulepath setting" do
        global_path_location = File.expand_path("global_path")
        global_path = FS::MemoryFile.a_directory(global_path_location)

        loader_from(:filesystem => [envdir, manifestdir, modulepath, global_path].flatten,
                    :directory => envdir,
                    :modulepath => [global_path]) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path))
        end
      end

      it "reads config_version setting" do
        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path)).
            with_config_version(File.expand_path('/some/script'))
        end
      end

      it "reads static_catalogs setting" do
        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path)).
            with_config_version(File.expand_path('/some/script')).
            with_static_catalogs(false)
        end
      end

      it "accepts an empty environment.conf without warning" do
        content = nil

        envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
          FS::MemoryFile.a_directory("env1", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", content),
          ]),
        ])

        manifestdir = FS::MemoryFile.a_directory(File.join(envdir, "env1", "manifests"))
        modulesdir = FS::MemoryFile.a_directory(File.join(envdir, "env1", "modules"))
        global_path_location = File.expand_path("global_path")
        global_path = FS::MemoryFile.a_directory(global_path_location)

        loader_from(:filesystem => [envdir, manifestdir, modulesdir, global_path].flatten,
                    :directory => envdir,
                    :modulepath => [global_path]) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest("#{FS.path_string(envdir)}/env1/manifests").
            with_modulepath(["#{FS.path_string(envdir)}/env1/modules", global_path_location]).
            with_config_version(nil).
            with_static_catalogs(true)
        end

        expect(@logs).to be_empty
      end

      it "logs a warning, but processes the main settings if there are extraneous sections" do
        content << "[foo]"
        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path)).
            with_config_version(File.expand_path('/some/script'))
        end

        expect(@logs.map(&:to_s).join).to match(/Invalid.*at.*\/env1.*may not have sections.*ignored: 'foo'/)
      end

      it "logs a warning, but processes the main settings if there are any extraneous settings" do
        content << "dog=arf\n"
        content << "cat=mew\n"
        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path)).
            with_config_version(File.expand_path('/some/script'))
        end

        expect(@logs.map(&:to_s).join).to match(/Invalid.*at.*\/env1.*unknown setting.*dog, cat/)
      end

      it "logs a warning, but processes the main settings if there are any ignored sections" do
        content << "dog=arf\n"
        content << "cat=mew\n"
        content << "[ignored]\n"
        content << "cow=moo\n"
        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path)).
            with_config_version(File.expand_path('/some/script'))
        end

        expect(@logs.map(&:to_s).join).to match(/Invalid.*at.*\/env1.*The following sections are being ignored: 'ignored'/)
        expect(@logs.map(&:to_s).join).to match(/Invalid.*at.*\/env1.*unknown setting.*dog, cat/)
      end

      it "interpretes relative paths from the environment's directory" do
        content = <<-EOF
manifest=relative/manifest
modulepath=relative/modules
config_version=relative/script
        EOF

        envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
          FS::MemoryFile.a_directory("env1", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", content),
            FS::MemoryFile.a_missing_file("modules"),
            FS::MemoryFile.a_directory('relative', [
              FS::MemoryFile.a_directory('modules'),
            ]),
          ]),
        ])

        loader_from(:filesystem => [envdir],
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(File.join(envdir, 'env1', 'relative', 'manifest')).
            with_modulepath([File.join(envdir, 'env1', 'relative', 'modules')]).
            with_config_version(File.join(envdir, 'env1', 'relative', 'script'))
        end
      end

      it "interprets glob modulepaths from the environment's directory" do
        Dir.stubs(:glob).with(File.join(envdir, 'env1', 'other', '*', 'modules')).returns([
          File.join(envdir, 'env1', 'other', 'foo', 'modules'),
          File.join(envdir, 'env1', 'other', 'bar', 'modules')
        ])
        content = <<-EOF
manifest=relative/manifest
modulepath=relative/modules#{File::PATH_SEPARATOR}other/*/modules
config_version=relative/script
        EOF

        envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
          FS::MemoryFile.a_directory("env1", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", content),
            FS::MemoryFile.a_missing_file("modules"),
            FS::MemoryFile.a_directory('relative', [
              FS::MemoryFile.a_directory('modules'),
            ]),
            FS::MemoryFile.a_directory('other', [
              FS::MemoryFile.a_directory('foo', [
                FS::MemoryFile.a_directory('modules'),
              ]),
              FS::MemoryFile.a_directory('bar', [
                FS::MemoryFile.a_directory('modules'),
              ]),
            ]),
          ]),
        ])

        loader_from(:filesystem => [envdir],
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(File.join(envdir, 'env1', 'relative', 'manifest')).
            with_modulepath([File.join(envdir, 'env1', 'relative', 'modules'),
                             File.join(envdir, 'env1', 'other', 'foo', 'modules'),
                             File.join(envdir, 'env1', 'other', 'bar', 'modules')]).
            with_config_version(File.join(envdir, 'env1', 'relative', 'script'))
        end
      end

      it "interpolates other setting values correctly" do
        modulepath = [
          File.expand_path('/some/absolute'),
          '$basemodulepath',
          'modules'
        ].join(File::PATH_SEPARATOR)

        content = <<-EOF
manifest=$confdir/whackymanifests
modulepath=#{modulepath}
config_version=$vardir/random/scripts
        EOF

        some_absolute_dir = FS::MemoryFile.a_directory(File.expand_path('/some/absolute'))
        base_module_dirs = Puppet[:basemodulepath].split(File::PATH_SEPARATOR).map do |path|
          FS::MemoryFile.a_directory(path)
        end
        envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
          FS::MemoryFile.a_directory("env1", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", content),
            FS::MemoryFile.a_directory("modules"),
          ]),
        ])

        loader_from(:filesystem => [envdir, some_absolute_dir, base_module_dirs].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(File.join(Puppet[:confdir], 'whackymanifests')).
            with_modulepath([some_absolute_dir.path,
                            base_module_dirs.map { |d| d.path },
                            File.join(envdir, 'env1', 'modules')].flatten).
            with_config_version(File.join(Puppet[:vardir], 'random', 'scripts'))
        end
      end

      it "uses environment.conf settings regardless of existence of modules and manifests subdirectories" do
        envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
          FS::MemoryFile.a_directory("env1", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", content),
            FS::MemoryFile.a_directory("modules"),
            FS::MemoryFile.a_directory("manifests"),
          ]),
        ])

        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path)).
            with_config_version(File.expand_path('/some/script'))
        end
      end

      it "should update environment settings if environment.conf has changed and timeout has expired" do
        base_dir = File.expand_path("envdir")
        original_envdir = FS::MemoryFile.a_directory(base_dir, [
          FS::MemoryFile.a_directory("env3", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", <<-EOF)
              manifest=/manifest_orig
              modulepath=/modules_orig
              environment_timeout=0
            EOF
          ]),
        ])

        FS.overlay(original_envdir) do
          dir_loader = Puppet::Environments::Directories.new(original_envdir, [])
          loader = Puppet::Environments::Cached.new(dir_loader)
          Puppet.override(:environments => loader) do
            original_env = loader.get("env3") # force the environment.conf to be read

            changed_envdir = FS::MemoryFile.a_directory(base_dir, [
              FS::MemoryFile.a_directory("env3", [
                FS::MemoryFile.a_regular_file_containing("environment.conf", <<-EOF)
                  manifest=/manifest_changed
                  modulepath=/modules_changed
                  environment_timeout=0
                EOF
              ]),
            ])

            FS.overlay(changed_envdir) do
              changed_env = loader.get("env3")

              expect(original_env).to environment(:env3).
                with_manifest(File.expand_path("/manifest_orig")).
                with_full_modulepath([File.expand_path("/modules_orig")])

              expect(changed_env).to environment(:env3).
                with_manifest(File.expand_path("/manifest_changed")).
                with_full_modulepath([File.expand_path("/modules_changed")])
            end
          end
        end
      end

      context "custom cache expiration service" do
        it "consults the custom service to expire the cache" do
          loader_from(:filesystem => [directory_tree],
                      :directory => directory_tree) do |loader|
            service = ReplayExpirationService.new([true])
            using_expiration_service(service) do

              cached = Puppet::Environments::Cached.new(loader)
              cached.get(:an_environment)
              cached.get(:an_environment)

              expect(service.created_envs).to include(:an_environment)
              expect(service.expired_envs).to include(:an_environment)
              expect(service.evicted_envs).to include(:an_environment)
            end
          end
        end
      end
    end
  end

  describe "static loaders" do
    let(:static1) { Puppet::Node::Environment.create(:static1, []) }
    let(:static2) { Puppet::Node::Environment.create(:static2, []) }
    let(:loader) { Puppet::Environments::Static.new(static1, static2) }

    it "lists environments" do
      expect(loader.list).to eq([static1, static2])
    end

    it "has search_paths" do
      expect(loader.search_paths).to eq(["data:text/plain,internal"])
    end

    it "gets an environment" do
      expect(loader.get(:static2)).to eq(static2)
    end

    it "returns nil if env not found" do
      expect(loader.get(:doesnotexist)).to be_nil
    end

    it "raises error if environment is not found" do
      expect do
        loader.get!(:doesnotexist)
      end.to raise_error(Puppet::Environments::EnvironmentNotFound)
    end

    it "gets a basic conf" do
      conf = loader.get_conf(:static1)
      expect(conf.modulepath).to eq('')
      expect(conf.manifest).to eq(:no_manifest)
      expect(conf.config_version).to be_nil
      expect(conf.static_catalogs).to eq(true)
    end

    it "returns nil if you request a configuration from an env that doesn't exist" do
      expect(loader.get_conf(:doesnotexist)).to be_nil
    end

    it "gets the conf environment_timeout if one is specified" do
      Puppet[:environment_timeout] = 8675
      conf = loader.get_conf(:static1)

      expect(conf.environment_timeout).to eq(8675)
    end

    context "that are private" do
      let(:private_env) { Puppet::Node::Environment.create(:private, []) }
      let(:loader) { Puppet::Environments::StaticPrivate.new(private_env) }

      it "lists nothing" do
        expect(loader.list).to eq([])
      end
    end
  end

  describe "combined loaders" do
    let(:static1) { Puppet::Node::Environment.create(:static1, []) }
    let(:static2) { Puppet::Node::Environment.create(:static2, []) }
    let(:static_loader) { Puppet::Environments::Static.new(static1, static2) }
    let(:directory_tree) do
      FS::MemoryFile.a_directory(File.expand_path("envdir"), [
        FS::MemoryFile.a_directory("an_environment", [
          FS::MemoryFile.a_missing_file("environment.conf"),
          FS::MemoryFile.a_directory("modules"),
          FS::MemoryFile.a_directory("manifests"),
        ]),
        FS::MemoryFile.a_missing_file("env_does_not_exist"),
        FS::MemoryFile.a_missing_file("static2"),
      ])
    end

    it "lists environments" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        envs = Puppet::Environments::Combined.new(loader, static_loader).list
        expect(envs[0]).to environment(:an_environment)
        expect(envs[1]).to environment(:static1)
        expect(envs[2]).to environment(:static2)
      end
    end

    it "has search_paths" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect(Puppet::Environments::Combined.new(loader, static_loader).search_paths).to eq(["file://#{directory_tree}","data:text/plain,internal"])
      end
    end

    it "gets an environment" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect(Puppet::Environments::Combined.new(loader, static_loader).get(:an_environment)).to environment(:an_environment)
        expect(Puppet::Environments::Combined.new(loader, static_loader).get(:static2)).to environment(:static2)
      end
    end

    it "returns nil if env not found" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect(Puppet::Environments::Combined.new(loader, static_loader).get(:env_does_not_exist)).to be_nil
      end
    end

    it "raises an error if environment is not found" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect do
          Puppet::Environments::Combined.new(loader, static_loader).get!(:env_does_not_exist)
        end.to raise_error(Puppet::Environments::EnvironmentNotFound)
      end
    end

    it "gets an environment.conf" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect(Puppet::Environments::Combined.new(loader, static_loader).get_conf(:an_environment)).to match_environment_conf(:an_environment).
          with_env_path(directory_tree).
          with_global_module_path([])
      end
    end
  end

  describe "cached loaders" do
    it "lists environments" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect(Puppet::Environments::Cached.new(loader).list).to include_in_any_order(
          environment(:an_environment),
          environment(:another_environment))
      end
    end

    it "has search_paths" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect(Puppet::Environments::Cached.new(loader).search_paths).to eq(["file://#{directory_tree}"])
      end
    end

    context "#get" do
      it "gets an environment" do
        loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
          expect(Puppet::Environments::Cached.new(loader).get(:an_environment)).to environment(:an_environment)
        end
      end

      it "does not reload the environment if it isn't expired" do
        env = Puppet::Node::Environment.create(:cached, [])
        mocked_loader = mock('loader')
        mocked_loader.expects(:get).with(:cached).returns(env).once
        mocked_loader.expects(:get_conf).with(:cached).returns(Puppet::Settings::EnvironmentConf.static_for(env, 20)).once

        cached = Puppet::Environments::Cached.new(mocked_loader)

        cached.get(:cached)
        cached.get(:cached)
      end

      it "returns nil if env not found" do
        loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
          expect(Puppet::Environments::Cached.new(loader).get(:doesnotexist)).to be_nil
        end
      end
    end

    context "#get!" do
      it "gets an environment" do
        loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
          expect(Puppet::Environments::Cached.new(loader).get!(:an_environment)).to environment(:an_environment)
        end
      end

      it "does not reload the environment if it isn't expired" do
        env = Puppet::Node::Environment.create(:cached, [])
        mocked_loader = mock('loader')
        mocked_loader.expects(:get).with(:cached).returns(env).once
        mocked_loader.expects(:get_conf).with(:cached).returns(Puppet::Settings::EnvironmentConf.static_for(env, 20)).once

        cached = Puppet::Environments::Cached.new(mocked_loader)

        cached.get!(:cached)
        cached.get!(:cached)
      end

      it "raises error if environment is not found" do
        loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
          expect do
            Puppet::Environments::Cached.new(loader).get!(:doesnotexist)
          end.to raise_error(Puppet::Environments::EnvironmentNotFound)
        end
      end
    end

    it "gets an environment.conf" do
      loader_from(:filesystem => [directory_tree], :directory => directory_tree) do |loader|
        expect(Puppet::Environments::Cached.new(loader).get_conf(:an_environment)).to match_environment_conf(:an_environment).
          with_env_path(directory_tree).
          with_global_module_path([])
      end
    end
  end

  RSpec::Matchers.define :environment do |name|
    match do |env|
      env.name == name &&
        (!@manifest || @manifest == env.manifest) &&
        (!@modulepath || @modulepath == env.modulepath) &&
        (!@full_modulepath || @full_modulepath == env.full_modulepath) &&
        (!@config_version || @config_version == env.config_version) &&
        (!@static_catalogs || @static_catalogs == env.static_catalogs?)
    end

    chain :with_manifest do |manifest|
      @manifest = manifest
    end

    chain :with_modulepath do |modulepath|
      @modulepath = modulepath
    end

    chain :with_full_modulepath do |full_modulepath|
      @full_modulepath = full_modulepath
    end

    chain :with_config_version do |config_version|
      @config_version = config_version
    end

    chain :with_static_catalogs do |static_catalogs|
      @static_catalogs = static_catalogs
    end

    description do
      "environment #{expected}" +
        (@manifest ? " with manifest #{@manifest}" : "") +
        (@modulepath ? " with modulepath [#{@modulepath.join(', ')}]" : "") +
        (@full_modulepath ? " with full_modulepath [#{@full_modulepath.join(', ')}]" : "") +
        (@config_version ? " with config_version #{@config_version}" : "") +
        (@static_catalogs ? " with static_catalogs #{@static_catalogs}" : "")
    end

    failure_message do |env|
      "expected <#{env.name}: modulepath = [#{env.full_modulepath.join(', ')}], manifest = #{env.manifest}, config_version = #{env.config_version}>, static_catalogs = #{env.static_catalogs?} to be #{description}"
    end
  end

  RSpec::Matchers.define :match_environment_conf do |env_name|
    match do |env_conf|
      env_conf.path_to_env =~ /#{env_name}$/ &&
        (!@env_path || File.join(@env_path,env_name.to_s) == env_conf.path_to_env) &&
        (!@global_modulepath || @global_module_path == env_conf.global_module_path)
    end

    chain :with_env_path do |env_path|
      @env_path = env_path.to_s
    end

    chain :with_global_module_path do |global_module_path|
      @global_module_path = global_module_path
    end

    description do
      "EnvironmentConf #{expected}" +
        " with path_to_env: #{@env_path ? @env_path : "*"}/#{env_name}" +
        (@global_module_path ? " with global_module_path [#{@global_module_path.join(', ')}]" : "")
    end

    failure_message do |env_conf|
      "expected #{env_conf.inspect} to be #{description}"
    end
  end

  def loader_from(options, &block)
    FS.overlay(*options[:filesystem]) do
      environments = Puppet::Environments::Directories.new(
        options[:directory],
        options[:modulepath] || []
      )
      Puppet.override(:environments => environments) do
        yield environments
      end
    end
  end

  def using_expiration_service(service)
    begin
      orig_svc = Puppet::Environments::Cached.cache_expiration_service
      Puppet::Environments::Cached.cache_expiration_service = service
      yield
    ensure
      Puppet::Environments::Cached.cache_expiration_service = orig_svc
    end
  end

  class ReplayExpirationService
    attr_reader :created_envs, :expired_envs, :evicted_envs

    def initialize(expiration_sequence)
      @created_envs = []
      @expired_envs = []
      @evicted_envs = []
      @expiration_sequence = expiration_sequence
    end

    def created(env)
      @created_envs << env.name
    end

    def expired?(env_name)
      # make expired? idempotent
      return true if @expired_envs.include? (env_name)
      @expired_envs << env_name
      @expiration_sequence.pop
    end

    def evicted(env_name)
      @evicted_envs << env_name
    end
  end

end
end
