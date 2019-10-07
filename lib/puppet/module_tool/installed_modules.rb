require 'pathname'

require 'puppet/forge'
require 'puppet/module_tool'

module Puppet::ModuleTool
  class InstalledModules < SemanticPuppet::Dependency::Source
    attr_reader :modules, :by_name

    def priority
      10
    end

    def initialize(env)
      @env = env
      modules = env.modules_by_path

      @fetched = []
      @modules = {}
      @by_name = {}
      env.modulepath.each do |path|
        modules[path].each do |mod|
          @by_name[mod.name] = mod
          next unless mod.has_metadata?
          release = ModuleRelease.new(self, mod)
          @modules[release.name] ||= release
        end
      end

      @modules.freeze
    end

    # Fetches {ModuleRelease} entries for each release of the named module.
    #
    # @param name [String] the module name to look up
    # @return [Array<SemanticPuppet::Dependency::ModuleRelease>] a list of releases for
    #         the given name
    # @see SemanticPuppet::Dependency::Source#fetch
    def fetch(name)
      name = name.tr('/', '-')

      if @modules.key? name
        @fetched << name
        [ @modules[name] ]
      else
        [ ]
      end
    end

    def fetched
      @fetched
    end

    class ModuleRelease < SemanticPuppet::Dependency::ModuleRelease
      attr_reader :mod, :metadata

      def initialize(source, mod)
        @mod = mod
        @metadata = mod.metadata
        name = mod.forge_name.tr('/', '-')
        begin
          version = SemanticPuppet::Version.parse(mod.version)
        rescue SemanticPuppet::Version::ValidationFailure
          Puppet.warning _("%{module_name} (%{path}) has an invalid version number (%{version}). The version has been set to 0.0.0. If you are the maintainer for this module, please update the metadata.json with a valid Semantic Version (http://semver.org).") % { module_name: mod.name, path: mod.path, version: mod.version }
          version = SemanticPuppet::Version.parse("0.0.0")
        end
        release = "#{name}@#{version}"

        super(source, name, version, {})

        if mod.dependencies
          mod.dependencies.each do |dependency|
            results = Puppet::ModuleTool.parse_module_dependency(release, dependency)
            dep_name, parsed_range, range = results

            add_constraint('initialize', dep_name, range.to_s) do |node|
              parsed_range === node.version
            end
          end
        end
      end

      def install_dir
        Pathname.new(@mod.path).dirname
      end

      def install(dir)
        # If we're already installed, there's no need for us to faff about.
      end

      def prepare
        # We're already installed; what preparation remains?
      end
    end
  end
end
