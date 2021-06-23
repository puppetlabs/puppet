require 'spec_helper'
require 'puppet/environments'
require 'puppet/file_system'

describe Puppet::Environments do
  FS = Puppet::FileSystem

  module FsRemove
    def remove
      @properties[:directory?] = false
      @properties[:exist?] = false
      @properties[:executable?] = false
    end
  end

  before(:each) do
    Puppet.settings.initialize_global_settings
    Puppet[:environment_timeout] = "unlimited"
    Puppet[:versioned_environment_dirs] = true
  end

  let(:directory_tree) do
    FS::MemoryFile.a_directory(File.expand_path("top_level_dir"), [
      FS::MemoryFile.a_directory("envdir", [
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
        FS::MemoryFile.a_symlink("symlinked_environment", File.expand_path(File.join("top_level_dir", "versioned_env")))]),
      FS::MemoryFile.a_directory("versioned_env", [
        FS::MemoryFile.a_regular_file_containing("environment.conf", ''),
        FS::MemoryFile.a_directory("modules"),
        FS::MemoryFile.a_directory("manifests"),
      ]),
      FS::MemoryFile.a_missing_file("missing")
    ])
  end

  describe "directories loader" do
    it "lists environments" do
      global_path_1_location = File.expand_path("global_path_1")
      global_path_2_location = File.expand_path("global_path_2")
      global_path_1 = FS::MemoryFile.a_directory(global_path_1_location)
      global_path_2 = FS::MemoryFile.a_directory(global_path_2_location)

      loader_from(:filesystem => [directory_tree, global_path_1, global_path_2],
                  :directory => directory_tree.children.first,
                  :modulepath => [global_path_1_location, global_path_2_location]) do |loader|
        expect(loader.list).to contain_exactly(
          environment(:an_environment).
            with_manifest("#{FS.path_string(directory_tree)}/envdir/an_environment/manifests").
            with_modulepath(["#{FS.path_string(directory_tree)}/envdir/an_environment/modules",
                             global_path_1_location,
                             global_path_2_location]),
          environment(:another_environment),
          environment(:symlinked_environment).
            with_manifest("#{FS.path_string(directory_tree)}/versioned_env/manifests").
            with_modulepath(["#{FS.path_string(directory_tree)}/versioned_env/modules",
                             global_path_1_location,
                             global_path_2_location]))
      end
    end

    it "has search_paths" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.first) do |loader|
        expect(loader.search_paths).to eq(["file://#{directory_tree.children.first}"])
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
        expect(loader.list).to contain_exactly(environment(:env1), environment(:env2))
      end
    end

    it "proceeds with non-existant env dir" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.last) do |loader|
        expect(loader.list).to eq([])
      end
    end

    it "gets a particular environment" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.first) do |loader|
        expect(loader.get("an_environment")).to environment(:an_environment)
      end
    end

    it "gets a symlinked environment" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.first) do |loader|
        expect(loader.get("symlinked_environment")).to environment(:symlinked_environment)
      end
    end

    it "ignores symlinked environments when `:versioned_environment_dirs` is false" do
      Puppet[:versioned_environment_dirs] = false
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.first) do |loader|
        expect(loader.get("symlinked_environment")).to be_nil
      end
    end

    it "raises error when environment not found" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.first) do |loader|
        expect do
          loader.get!("doesnotexist")
        end.to raise_error(Puppet::Environments::EnvironmentNotFound)
      end
    end

    it "returns nil if an environment can't be found" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.first) do |loader|
        expect(loader.get("doesnotexist")).to be_nil
      end
    end

    it "implements guard and unguard" do
      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree.children.first) do |loader|
        expect(loader.guard('env1')).to be_nil
        expect(loader.unguard('env1')).to be_nil
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
        allow(Dir).to receive(:glob).with(File.join(envdir, 'env1', 'other', '*', 'modules')).and_return([
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

        cached_loader_from(:filesystem => [original_envdir], :directory => original_envdir) do |loader|
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
      cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
        expect(loader.list).to contain_exactly(
          environment(:an_environment),
          environment(:another_environment),
          environment(:symlinked_environment))
      end
    end

    it "returns the same cached environment object for list and get methods" do
      cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
        env = loader.list.find { |e| e.name == :an_environment }

        expect(env).to equal(loader.get(:an_environment)) # same object
      end
    end

    it "returns the same cached environment object for multiple list calls" do
      cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
        expect(loader.list.first).to equal(loader.list.first) # same object
      end
    end

    it "expires environments and returns a new environment object with the same value" do
      Puppet[:environment_timeout] = "0"

      cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
        a = loader.list.first
        b = loader.list.first
        expect(a).to eq(b)        # same value
        expect(a).to_not equal(b) # not same object
      end
    end

    it "has search_paths" do
      cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
        expect(loader.search_paths).to eq(["file://#{directory_tree.children.first}"])
      end
    end

    context "#get" do
      it "gets an environment" do
        cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
          expect(loader.get(:an_environment)).to environment(:an_environment)
        end
      end

      it "does not reload the environment if it isn't expired" do
        env = Puppet::Node::Environment.create(:cached, [])
        mocked_loader = double('loader')
        expect(mocked_loader).to receive(:get).with(:cached).and_return(env).once
        expect(mocked_loader).to receive(:get_conf).with(:cached).and_return(Puppet::Settings::EnvironmentConf.static_for(env, 20)).once

        cached = Puppet::Environments::Cached.new(mocked_loader)

        cached.get(:cached)
        cached.get(:cached)
      end

      it "does not list deleted environments" do
        env3 = FS::MemoryFile.a_directory("env3", [
          FS::MemoryFile.a_regular_file_containing("environment.conf", '')
        ])

        envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
          FS::MemoryFile.a_directory("env1", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", '')
          ]),
          FS::MemoryFile.a_directory("env2", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", '')
          ]),
          env3
        ])

        loader_from(:filesystem => [envdir], :directory => envdir) do |loader|
          cached = Puppet::Environments::Cached.new(loader)
          cached.get(:env1)
          cached.get(:env2)
          cached.get(:env3)
          env3.extend(FsRemove).remove

          expect(cached.list).to contain_exactly(environment(:env1),environment(:env2))
          expect(cached.get(:env3)).to be_nil
        end
      end

      it "normalizes environment name to symbol" do
        env = Puppet::Node::Environment.create(:cached, [])
        mocked_loader = double('loader')

        expect(mocked_loader).not_to receive(:get).with('cached')
        expect(mocked_loader).to receive(:get).with(:cached).and_return(env).once
        expect(mocked_loader).to receive(:get_conf).with(:cached).and_return(Puppet::Settings::EnvironmentConf.static_for(env, 20)).once

        cached = Puppet::Environments::Cached.new(mocked_loader)
        cached.get('cached')
        cached.get(:cached)
      end

      it "caches environment name as symbol and only once" do
        mocked_loader = double('loader')

        env = Puppet::Node::Environment.create(:cached, [])
        allow(mocked_loader).to receive(:get).with(:cached).and_return(env)
        allow(mocked_loader).to receive(:get_conf).with(:cached).and_return(Puppet::Settings::EnvironmentConf.static_for(env, 20))

        cached = Puppet::Environments::Cached.new(mocked_loader)
        cached.get(:cached)
        cached.get('cached')

        expect(cached.instance_variable_get(:@cache).keys).to eq([:cached])
      end

      it "is able to cache multiple environments" do
        mocked_loader = double('loader')

        env1 = Puppet::Node::Environment.create(:env1, [])
        allow(mocked_loader).to receive(:get).with(:env1).and_return(env1)
        allow(mocked_loader).to receive(:get_conf).with(:env1).and_return(Puppet::Settings::EnvironmentConf.static_for(env1, 20))

        env2 = Puppet::Node::Environment.create(:env2, [])
        allow(mocked_loader).to receive(:get).with(:env2).and_return(env2)
        allow(mocked_loader).to receive(:get_conf).with(:env2).and_return(Puppet::Settings::EnvironmentConf.static_for(env2, 20))

        cached = Puppet::Environments::Cached.new(mocked_loader)
        cached.get('env1')
        cached.get('env2')

        expect(cached.instance_variable_get(:@cache).keys).to eq([:env1, :env2])
      end

      it "returns nil if env not found" do
        cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
          expect(loader.get(:doesnotexist)).to be_nil
        end
      end
    end

    context "#get!" do
      it "gets an environment" do
        cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
          expect(loader.get!(:an_environment)).to environment(:an_environment)
        end
      end

      it "does not reload the environment if it isn't expired" do
        env = Puppet::Node::Environment.create(:cached, [])
        mocked_loader = double('loader')
        expect(mocked_loader).to receive(:get).with(:cached).and_return(env).once
        expect(mocked_loader).to receive(:get_conf).with(:cached).and_return(Puppet::Settings::EnvironmentConf.static_for(env, 20)).once

        cached = Puppet::Environments::Cached.new(mocked_loader)

        cached.get!(:cached)
        cached.get!(:cached)
      end

      it "raises error if environment is not found" do
        cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
          expect do
            loader.get!(:doesnotexist)
          end.to raise_error(Puppet::Environments::EnvironmentNotFound)
        end
      end
    end

    context "#get_conf" do
      it "loads environment.conf" do
        cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
          expect(loader.get_conf(:an_environment)).to match_environment_conf(:an_environment).
            with_env_path(directory_tree.children.first).
            with_global_module_path([])
        end
      end

      it "always reloads environment.conf" do
        env = Puppet::Node::Environment.create(:cached, [])
        mocked_loader = double('loader')
        expect(mocked_loader).to receive(:get_conf).with(:cached).and_return(Puppet::Settings::EnvironmentConf.static_for(env, 20)).twice

        cached = Puppet::Environments::Cached.new(mocked_loader)

        cached.get_conf(:cached)
        cached.get_conf(:cached)
      end

      it "normalizes environment name to symbol" do
        env = Puppet::Node::Environment.create(:cached, [])
        mocked_loader = double('loader')
        expect(mocked_loader).to receive(:get_conf).with(:cached).and_return(Puppet::Settings::EnvironmentConf.static_for(env, 20)).twice

        cached = Puppet::Environments::Cached.new(mocked_loader)

        cached.get_conf('cached')
        cached.get_conf(:cached)
      end

      it "returns nil if environment is not found" do
        cached_loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
          expect(loader.get_conf(:doesnotexist)).to be_nil
        end
      end
    end

    context "expiration policies" do
      let(:service) { ReplayExpirationService.new }

      it "notifies when the environment is first created" do
        with_environment_loaded(service)

        expect(service.created_envs).to eq([:an_environment])
      end

      it "does not evict an unexpired environment" do
        Puppet[:environment_timeout] = 'unlimited'

        with_environment_loaded(service) do |cached|
          cached.get!(:an_environment)
        end

        expect(service.created_envs).to eq([:an_environment])
        expect(service.evicted_envs).to eq([])
      end

      it "evicts an expired environment" do
        expect(service).to receive(:expired?).and_return(true)

        with_environment_loaded(service) do |cached|
          cached.get!(:an_environment)
        end

        expect(service.created_envs).to eq([:an_environment, :an_environment])
        expect(service.evicted_envs).to eq([:an_environment])
      end

      it "evicts an environment that hasn't been recently touched" do
        Puppet[:environment_timeout] = 1
        Puppet[:environment_timeout_mode] = :from_last_used

        with_environment_loaded(service) do |cached|
          future = Time.now + 60
          expect(Time).to receive(:now).and_return(future).at_least(:once)

          # this should cause the cached environment to be evicted and a new one created
          cached.get!(:an_environment)
        end

        expect(service.created_envs).to eq([:an_environment, :an_environment])
        expect(service.evicted_envs).to eq([:an_environment])

      end

      it "reuses an environment that was recently touched" do
        Puppet[:environment_timeout] = 60
        Puppet[:environment_timeout_mode] = :from_last_used

        with_environment_loaded(service) do |cached|
          # reuse the already cached environment
          cached.get!(:an_environment)
        end

        expect(service.created_envs).to eq([:an_environment])
        expect(service.evicted_envs).to eq([])
      end

      it "evicts a recently touched environment" do
        Puppet[:environment_timeout] = 60
        Puppet[:environment_timeout_mode] = :from_last_used

        expect(service).to receive(:expired?).and_return(true)

        with_environment_loaded(service) do |cached|
          # even though the environment was recently touched, it's been expired
          cached.get!(:an_environment)
        end

        expect(service.created_envs).to eq([:an_environment, :an_environment])
        expect(service.evicted_envs).to eq([:an_environment])
      end

      it "evicts expired environments when listing" do
        expect(service).to receive(:expired?).with(:an_environment).and_return(true)

        with_environment_loaded(service) do |cached|
          cached.list
        end

        expect(service.evicted_envs).to eq([:an_environment])
      end

      context "when guarding an environment" do
        before :each do
          Puppet[:environment_timeout] = 0
        end

        let(:name) { :an_environment }

        def with_guard(cached, name, &block)
          cached.guard(name)
          begin
            yield
          ensure
            cached.unguard(name)
          end
        end

        it "evicts an expired and unguarded environment" do
          with_environment_loaded(service) do |cached|
            cached.get!(name)
          end

          expect(service.created_envs).to eq([name, name])
          expect(service.evicted_envs).to eq([name])
        end

        it "does not evict an expired, but guarded environment" do
          with_environment_loaded(service) do |cached|
            with_guard(cached, name) do
              cached.get!(name) # these shouldn't reload
              cached.get!(name)
            end
          end

          expect(service.created_envs).to eq([name])
          expect(service.evicted_envs).to eq([])
        end

        it "does not evict an environment marked for expiration, but is guarded" do
          Puppet[:environment_timeout] = 'unlimited'

          expect(service).to receive(:expired?).never

          with_environment_loaded(service) do |cached|
            with_guard(cached, name) do
              cached.get!(name)
            end
          end

          expect(service.created_envs).to eq([name])
          expect(service.evicted_envs).to eq([])
        end

        it "evicts an environment that is no longer guarded" do
          with_environment_loaded(service) do |cached|
            with_guard(cached, name) {}

            cached.get!(name) # this reloads
          end

          expect(service.created_envs).to eq([name, name])
          expect(service.evicted_envs).to eq([name])
        end

        it "can nest guards" do
          with_environment_loaded(service) do |cached|
            with_guard(cached, name) do
              with_guard(cached, name) do
                cached.get!(name) # doesn't reload
              end
            end
          end

          expect(service.created_envs).to eq([name])
          expect(service.evicted_envs).to eq([])
        end
      end
    end

    context '#clear' do
      let(:service) { ReplayExpirationService.new }

      it "evicts an environment" do
        with_environment_loaded(service) do |cached|
          cached.clear(:an_environment)
        end

        expect(service.evicted_envs).to eq([:an_environment])
      end

      it "normalizes environment name to symbol" do
        with_environment_loaded(service) do |cached|
          cached.clear('an_environment')
        end

        expect(service.evicted_envs).to eq([:an_environment])
      end
    end

    context '#clear_all' do
      let(:service) { ReplayExpirationService.new }
      let(:envdir) { File.expand_path("envdir") }
      let(:default_dir) { File.join(envdir, "cached_env", "modules") }
      let(:expected_dir) { File.join(envdir, "cached_env", "site") }

      let(:base_dir) do
        FS::MemoryFile.a_directory(envdir, [
          FS::MemoryFile.a_directory("cached_env", [
            FS::MemoryFile.a_missing_file("environment.conf")
          ])
        ])
      end

      let(:updated_dir) do
        FS::MemoryFile.a_directory(envdir, [
          FS::MemoryFile.a_directory("cached_env", [
            FS::MemoryFile.a_directory("site"),
            FS::MemoryFile.a_missing_directory("modules"),
            FS::MemoryFile.a_regular_file_containing("environment.conf", <<-EOF)
              modulepath=site
              environment_timeout=unlimited
            EOF
          ])
        ])
      end

      it 'evicts all environments' do
        with_environment_loaded(service) do |cached|
          cached.get(:an_environment)
          cached.get(:another_environment)
          cached.clear_all

          expect(service.evicted_envs).to match([:an_environment, :another_environment])
        end
      end

      it "recomputes modulepath if 'get' is called before 'clear_all'" do
        cached_loader_from(:filesystem => [base_dir], :directory => base_dir) do |loader|
          loader.get(:cached_env)

          expect(Puppet.settings.value(:modulepath, :cached_env)).to eq(default_dir)

          FS.overlay(updated_dir) do
            loader.clear_all

            expect(loader.get(:cached_env).modulepath).to contain_exactly(expected_dir)
          end
        end
      end

      it "recomputes modulepath if 'list' is called before 'clear_all'"  do
        cached_loader_from(:filesystem => [base_dir], :directory => base_dir) do |loader|
          loader.list

          expect(Puppet.settings.value(:modulepath, :cached_env)).to eq(default_dir)

          FS.overlay(updated_dir) do
            loader.clear_all

            expect(loader.get(:cached_env).modulepath).to contain_exactly(expected_dir)
          end
        end
      end

      it "recomputes modulepath if 'get_conf' is called before 'clear_all'" do
        cached_loader_from(:filesystem => [base_dir], :directory => base_dir) do |loader|
          loader.get_conf(:cached_env)

          expect(Puppet.settings.value(:modulepath, :cached_env)).to eq(default_dir)

          FS.overlay(updated_dir) do
            loader.clear_all

            expect(loader.get(:cached_env).modulepath).to contain_exactly(expected_dir)
          end
        end
      end

      it 'deletes environment text domains' do
        with_environment_loaded(service) do |cached|
          cached.get(:an_environment)
          cached.clear_all

          expect(FastGettext.text_domain).to eq(Puppet::GettextConfig::DEFAULT_TEXT_DOMAIN)
        end
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

  def cached_loader_from(options, &block)
    FS.overlay(*options[:filesystem]) do
      environments = Puppet::Environments::Cached.new(
        Puppet::Environments::Directories.new(
          options[:directory],
          options[:modulepath] || []
        )
      )
      Puppet.override(:environments => environments) do
        yield environments
      end
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

  # The environment named `:an_environment` will already be loaded when the
  # block is yielded to
  def with_environment_loaded(service, &block)
    loader_from(:filesystem => [directory_tree], :directory => directory_tree.children.first) do |loader|
      using_expiration_service(service) do
        cached = Puppet::Environments::Cached.new(loader)
        cached.get!(:an_environment)

        yield cached if block_given?
      end
    end
  end

  class ReplayExpirationService < Puppet::Environments::Cached::DefaultCacheExpirationService
    attr_reader :created_envs, :evicted_envs

    def initialize
      @created_envs = []
      @evicted_envs = []
    end

    def created(env)
      @created_envs << env.name
    end

    def evicted(env_name)
      @evicted_envs << env_name
    end
  end
end
