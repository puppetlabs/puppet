require 'pathname'
require 'tmpdir'

require 'puppet/forge'
require 'puppet/module_tool'

module Puppet::ModuleTool
  class LocalTarball < Semantic::Dependency::Source
    attr_accessor :release

    def initialize(filename)
      unpack(filename, tmpdir)
      Puppet.debug "Unpacked local tarball to #{tmpdir}"

      mod = Puppet::Module.new('tarball', tmpdir, nil)
      @release = ModuleRelease.new(self, mod)
    end

    def fetch(name)
      if @release.name == name
        [ @release ]
      else
        [ ]
      end
    end

    def prepare(release)
      release.mod.path
    end

    def install(release, dir)
      staging_dir = release.prepare

      module_dir = dir + release.name[/-(.*)/, 1]
      module_dir.rmtree if module_dir.exist?

      # Make sure unpacked module has the same ownership as the folder we are moving it into.
      Puppet::ModuleTool::Applications::Unpacker.harmonize_ownership(dir, staging_dir)

      FileUtils.mv(staging_dir, module_dir)
    end

    class ModuleRelease < Semantic::Dependency::ModuleRelease
      attr_reader :mod, :install_dir, :metadata

      def initialize(source, mod)
        @mod = mod
        @metadata = mod.metadata
        name = mod.forge_name.tr('/', '-')
        version = Semantic::Version.parse(mod.version)
        release = "#{name}@#{version}"

        if mod.dependencies
          dependencies = mod.dependencies.map do |dep|
            Puppet::ModuleTool.parse_module_dependency(release, dep)[0..1]
          end
          dependencies = Hash[dependencies]
        end

        super(source, name, version, dependencies || {})
      end

      def install(dir)
        @source.install(self, dir)
        @install_dir = dir
      end

      def prepare
        @source.prepare(self)
      end
    end

    private

    # Obtain a suitable temporary path for unpacking tarballs
    #
    # @return [String] path to temporary unpacking location
    def tmpdir
      @dir ||= Dir.mktmpdir('local-tarball', Puppet::Forge::Cache.base_path)
    end

    def unpack(file, destination)
      begin
        Puppet::ModuleTool::Applications::Unpacker.unpack(file, destination)
      rescue Puppet::ExecutionFailure => e
        raise RuntimeError, "Could not extract contents of module archive: #{e.message}"
      end
    end
  end
end
