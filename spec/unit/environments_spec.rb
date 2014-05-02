require 'spec_helper'
require 'puppet/environments'
require 'puppet/file_system'
require 'matchers/include'

module PuppetEnvironments
describe Puppet::Environments do
  include Matchers::Include

  FS = Puppet::FileSystem

  describe "directories loader" do
    before(:each) do
      Puppet.settings.initialize_global_settings
    end

    it "lists environments" do
      global_path_1_location = File.expand_path("global_path_1")
      global_path_2_location = File.expand_path("global_path_2")
      global_path_1 = FS::MemoryFile.a_directory(global_path_1_location)
      global_path_2 = FS::MemoryFile.a_directory(global_path_2_location)

      envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
        FS::MemoryFile.a_directory("env1", [
          FS::MemoryFile.a_missing_file("environment.conf"),
          FS::MemoryFile.a_directory("modules"),
          FS::MemoryFile.a_directory("manifests"),
        ]),
        FS::MemoryFile.a_directory("env2", [
          FS::MemoryFile.a_missing_file("environment.conf"),
        ]),
      ])

      loader_from(:filesystem => [envdir, global_path_1, global_path_2],
                  :directory => envdir,
                  :modulepath => [global_path_1_location, global_path_2_location]) do |loader|
        expect(loader.list).to include_in_any_order(
          environment(:env1).
            with_manifest("#{FS.path_string(envdir)}/env1/manifests").
            with_modulepath(["#{FS.path_string(envdir)}/env1/modules",
                             global_path_1_location,
                             global_path_2_location]),
          environment(:env2))
      end
    end

    it "does not list files" do
      envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
        FS::MemoryFile.a_regular_file_containing("foo", ''),
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
      directory_tree = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
        FS::MemoryFile.a_directory("env1", [
          FS::MemoryFile.a_missing_file("environment.conf"),
        ]),
        FS::MemoryFile.a_directory("env2", [
          FS::MemoryFile.a_missing_file("environment.conf"),
        ]),
      ])

      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect(loader.get("env1")).to environment(:env1)
      end
    end

    it "returns nil if an environment can't be found" do
      directory_tree = FS::MemoryFile.a_directory("envdir", [])

      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect(loader.get("env_not_in_this_list")).to be_nil
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
            with_config_version(nil)
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
        content << "[ignored]\n"
        content << "cow=moo\n"
        loader_from(:filesystem => [envdir, manifestdir, modulepath].flatten,
                    :directory => envdir) do |loader|
          expect(loader.get("env1")).to environment(:env1).
            with_manifest(manifestdir.path).
            with_modulepath(modulepath.map(&:path)).
            with_config_version(File.expand_path('/some/script'))
        end

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
    end
  end

  describe "static loaders" do
    let(:static1) { Puppet::Node::Environment.create(:static1, []) }
    let(:static2) { Puppet::Node::Environment.create(:static2, []) }
    let(:loader) { Puppet::Environments::Static.new(static1, static2) }

    it "lists environments" do
      expect(loader.list).to eq([static1, static2])
    end

    it "gets an environment" do
      expect(loader.get(:static2)).to eq(static2)
    end

    it "returns nil if env not found" do
      expect(loader.get(:doesnotexist)).to be_nil
    end

    it "gets a basic conf" do
      conf = loader.get_conf(:static1)
      expect(conf.modulepath).to eq('')
      expect(conf.manifest).to eq(:no_manifest)
      expect(conf.config_version).to be_nil
    end

    it "returns nil if you request a configuration from an env that doesn't exist" do
      expect(loader.get_conf(:doesnotexist)).to be_nil
    end

    context "that are private" do
      let(:private_env) { Puppet::Node::Environment.create(:private, []) }
      let(:loader) { Puppet::Environments::StaticPrivate.new(private_env) }

      it "lists nothing" do
        expect(loader.list).to eq([])
      end
    end
  end

  RSpec::Matchers.define :environment do |name|
    match do |env|
      env.name == name &&
        (!@manifest || @manifest == env.manifest) &&
        (!@modulepath || @modulepath == env.modulepath) &&
        (!@config_version || @config_version == env.config_version)
    end

    chain :with_manifest do |manifest|
      @manifest = manifest
    end

    chain :with_modulepath do |modulepath|
      @modulepath = modulepath
    end

    chain :with_config_version do |config_version|
      @config_version = config_version
    end

    description do
      "environment #{expected}" +
        (@manifest ? " with manifest #{@manifest}" : "") +
        (@modulepath ? " with modulepath [#{@modulepath.join(', ')}]" : "") +
        (@config_version ? " with config_version #{@config_version}" : "")
    end

    failure_message_for_should do |env|
      "expected <#{env.name}: modulepath = [#{env.modulepath.join(', ')}], manifest = #{env.manifest}, config_version = #{env.config_version}> to be #{description}"
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
end
end
