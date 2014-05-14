require 'pathname'

require 'puppet/forge'
require 'puppet/module_tool'

module Puppet::ModuleTool
  class InstalledModules < Semantic::Dependency::Source
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
    # @return [Array<Semantic::Dependency::ModuleRelease>] a list of releases for
    #         the given name
    # @see Semantic::Dependency::Source#fetch
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

    class ModuleRelease < Semantic::Dependency::ModuleRelease
      attr_reader :mod, :metadata

      def initialize(source, mod)
        @mod = mod
        @metadata = mod.metadata
        name = mod.forge_name.tr('/', '-')
        version = Semantic::Version.parse(mod.version)
        release = "#{name}@#{version}"

        super(source, name, version, {})

        if mod.dependencies
          mod.dependencies.each do |dep|
            results = Puppet::ModuleTool.parse_module_dependency(release, dep)
            dep_name, parsed_range, range = results

            dep.tap do |dep|
              add_constraint('initialize', dep_name, range.to_s) do |node|
                parsed_range === node.version
              end
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
