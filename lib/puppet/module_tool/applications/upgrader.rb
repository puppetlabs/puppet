require 'pathname'

require 'puppet/forge'
require 'puppet/module_tool'
require 'puppet/module_tool/shared_behaviors'
require 'puppet/module_tool/install_directory'
require 'puppet/module_tool/installed_modules'

module Puppet::ModuleTool
  module Applications
    class Upgrader < Application

      include Puppet::ModuleTool::Errors

      def initialize(name, options)
        super(options)

        @action              = :upgrade
        @environment         = options[:environment_instance]
        @name                = name
        @ignore_changes      = forced? || options[:ignore_changes]
        @ignore_dependencies = forced? || options[:ignore_dependencies]

        Semantic::Dependency.add_source(installed_modules_source)
        Semantic::Dependency.add_source(module_repository)
      end

      def run
        name = @name.tr('/', '-')
        version = options[:version] || '>= 0.0.0'

        results = {
          :action => :upgrade,
          :requested_version => options[:version] || :latest,
        }

        begin
          all_modules = @environment.modules_by_path.values.flatten
          matching_modules = all_modules.select do |x|
            x.forge_name && x.forge_name.tr('/', '-') == name
          end

          if matching_modules.empty?
            raise NotInstalledError, results.merge(:module_name => name)
          elsif matching_modules.length > 1
            raise MultipleInstalledError, results.merge(:module_name => name, :installed_modules => matching_modules)
          end

          installed_release = installed_modules[name]

          # `priority` is an attribute of a `Semantic::Dependency::Source`,
          # which is delegated through `ModuleRelease` instances for the sake of
          # comparison (sorting). By default, the `InstalledModules` source has
          # a priority of 10 (making it the most preferable source, so that
          # already installed versions of modules are selected in preference to
          # modules from e.g. the Forge). Since we are specifically looking to
          # upgrade this module, we don't want the installed version of this
          # module to be chosen in preference to those with higher versions.
          #
          # This implementation is suboptimal, and since we can expect this sort
          # of behavior to be reasonably common in Semantic, we should probably
          # see about implementing a `ModuleRelease#override_priority` method
          # (or something similar).
          def installed_release.priority
            0
          end

          mod = installed_release.mod
          results[:installed_version] = Semantic::Version.parse(mod.version)
          dir = Pathname.new(mod.modulepath)

          vstring = mod.version ? "v#{mod.version}" : '???'
          Puppet.notice "Found '#{name}' (#{colorize(:cyan, vstring)}) in #{dir} ..."
          unless @ignore_changes
            changes = Checksummer.run(mod.path) rescue []
            if mod.has_metadata? && !changes.empty?
              raise LocalChangesError,
                :action            => :upgrade,
                :module_name       => name,
                :requested_version => results[:requested_version],
                :installed_version => mod.version
            end
          end

          Puppet::Forge::Cache.clean

          # Ensure that there is at least one candidate release available
          # for the target package.
          available_versions = module_repository.fetch(name)
          if available_versions.empty?
            raise NoCandidateReleasesError, results.merge(:module_name => name, :source => module_repository.host)
          elsif results[:requested_version] != :latest
            requested = Semantic::VersionRange.parse(results[:requested_version])
            unless available_versions.any? {|m| requested.include? m.version}
              raise NoCandidateReleasesError, results.merge(:module_name => name, :source => module_repository.host)
            end
          end

          Puppet.notice "Downloading from #{module_repository.host} ..."
          if @ignore_dependencies
            graph = build_single_module_graph(name, version)
          else
            graph = build_dependency_graph(name, version)
          end

          unless forced?
            add_module_name_constraints_to_graph(graph)
          end

          installed_modules.each do |installed_module, release|
            installed_module = installed_module.tr('/', '-')
            next if installed_module == name

            version = release.version

            unless forced?
              # Since upgrading already installed modules can be troublesome,
              # we'll place constraints on the graph for each installed
              # module, locking it to upgrades within the same major version.
              installed_range = ">=#{version} #{version.major}.x"
              graph.add_constraint('installed', installed_module, installed_range) do |node|
                Semantic::VersionRange.parse(installed_range).include? node.version
              end

              release.mod.dependencies.each do |dep|
                dep_name = dep['name'].tr('/', '-')

                range = dep['version_requirement']
                graph.add_constraint("#{installed_module} constraint", dep_name, range) do |node|
                  Semantic::VersionRange.parse(range).include? node.version
                end
              end
            end
          end

          begin
            Puppet.info "Resolving dependencies ..."
            releases = Semantic::Dependency.resolve(graph)
          rescue Semantic::Dependency::UnsatisfiableGraph
            raise NoVersionsSatisfyError, results.merge(:requested_name => name)
          end

          releases.each do |rel|
            if mod = installed_modules_source.by_name[rel.name.split('-').last]
              next if mod.has_metadata? && mod.forge_name.tr('/', '-') == rel.name

              if rel.name != name
                dependency = {
                  :name => rel.name,
                  :version => rel.version
                }
              end

              raise InstallConflictError,
                :requested_module  => name,
                :requested_version => options[:version] || 'latest',
                :dependency        => dependency,
                :directory         => mod.path,
                :metadata          => mod.metadata
            end
          end

          child = releases.find { |x| x.name == name }

          unless forced?
            if child.version == results[:installed_version]
              versions = graph.dependencies[name].map { |r| r.version }
              newer_versions = versions.select { |v| v > results[:installed_version] }

              raise VersionAlreadyInstalledError,
                :module_name       => name,
                :requested_version => results[:requested_version],
                :installed_version => results[:installed_version],
                :newer_versions    => newer_versions,
                :possible_culprits => installed_modules_source.fetched.reject { |x| x == name }
            elsif child.version < results[:installed_version]
              raise DowngradingUnsupportedError,
                :module_name       => name,
                :requested_version => results[:requested_version],
                :installed_version => results[:installed_version]
            end
          end

          Puppet.info "Preparing to upgrade ..."
          releases.each { |release| release.prepare }

          Puppet.notice 'Upgrading -- do not interrupt ...'
          releases.each do |release|
            if installed = installed_modules[release.name]
              release.install(Pathname.new(installed.mod.modulepath))
            else
              release.install(dir)
            end
          end

          results[:result] = :success
          results[:base_dir] = releases.first.install_dir
          results[:affected_modules] = releases
          results[:graph] = [ build_install_graph(releases.first, releases) ]

        rescue VersionAlreadyInstalledError => e
          results[:result] = (e.newer_versions.empty? ? :noop : :failure)
          results[:error] = { :oneline => e.message, :multiline => e.multiline }
        rescue => e
          results[:error] = {
            :oneline   => e.message,
            :multiline => e.respond_to?(:multiline) ? e.multiline : [e.to_s, e.backtrace].join("\n")
          }
        ensure
          results[:result] ||= :failure
        end

        results
      end

      private
      def module_repository
        @repo ||= Puppet::Forge.new
      end

      def installed_modules_source
        @installed ||= Puppet::ModuleTool::InstalledModules.new(@environment)
      end

      def installed_modules
        installed_modules_source.modules
      end

      def build_single_module_graph(name, version)
        range = Semantic::VersionRange.parse(version)
        graph = Semantic::Dependency::Graph.new(name => range)
        releases = Semantic::Dependency.fetch_releases(name)
        releases.each { |release| release.dependencies.clear }
        graph << releases
      end

      def build_dependency_graph(name, version)
        Semantic::Dependency.query(name => version)
      end

      def build_install_graph(release, installed, graphed = [])
        previous = installed_modules[release.name]
        previous = previous.version if previous

        action = :upgrade
        unless previous && previous != release.version
          action = :install
        end

        graphed << release

        dependencies = release.dependencies.values.map do |deps|
          dep = (deps & installed).first
          if dep == installed_modules[dep.name]
            next
          end

          if dep && !graphed.include?(dep)
            build_install_graph(dep, installed, graphed)
          end
        end.compact

        return {
          :release          => release,
          :name             => release.name,
          :path             => release.install_dir,
          :dependencies     => dependencies.compact,
          :version          => release.version,
          :previous_version => previous,
          :action           => action,
        }
      end

      include Puppet::ModuleTool::Shared
    end
  end
end
