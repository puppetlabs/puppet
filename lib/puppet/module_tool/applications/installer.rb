# frozen_string_literal: true

require 'open-uri'
require 'pathname'
require 'fileutils'
require 'tmpdir'

require_relative '../../../puppet/forge'
require_relative '../../../puppet/module_tool'
require_relative '../../../puppet/module_tool/shared_behaviors'
require_relative '../../../puppet/module_tool/install_directory'
require_relative '../../../puppet/module_tool/local_tarball'
require_relative '../../../puppet/module_tool/installed_modules'
require_relative '../../../puppet/network/uri'

module Puppet::ModuleTool
  module Applications
    class Installer < Application
      include Puppet::ModuleTool::Errors
      include Puppet::Forge::Errors
      include Puppet::Network::Uri

      def initialize(name, install_dir, options = {})
        super(options)

        @action              = :install
        @environment         = options[:environment_instance]
        @ignore_dependencies = forced? || options[:ignore_dependencies]
        @name                = name
        @install_dir         = install_dir

        Puppet::Forge::Cache.clean

        @local_tarball = Puppet::FileSystem.exist?(name)

        if @local_tarball
          release = local_tarball_source.release
          @name = release.name
          options[:version] = release.version.to_s
          SemanticPuppet::Dependency.add_source(local_tarball_source)

          # If we're operating on a local tarball and ignoring dependencies, we
          # don't need to search any additional sources.  This will cut down on
          # unnecessary network traffic.
          unless @ignore_dependencies
            SemanticPuppet::Dependency.add_source(installed_modules_source)
            SemanticPuppet::Dependency.add_source(module_repository)
          end

        else
          SemanticPuppet::Dependency.add_source(installed_modules_source) unless forced?
          SemanticPuppet::Dependency.add_source(module_repository)
        end
      end

      def run
        name = @name.tr('/', '-')
        version = options[:version] || '>= 0.0.0'

        results = { :action => :install, :module_name => name, :module_version => version }

        begin
          if !@local_tarball && name !~ /-/
            raise InvalidModuleNameError.new(module_name: @name, suggestion: "puppetlabs-#{@name}", action: :install)
          end

          installed_module = installed_modules[name]
          if installed_module
            unless forced?
              if Puppet::Module.parse_range(version).include? installed_module.version
                results[:result] = :noop
                results[:version] = installed_module.version
                return results
              else
                changes = Checksummer.run(installed_modules[name].mod.path) rescue []
                raise AlreadyInstalledError,
                      :module_name => name,
                      :installed_version => installed_modules[name].version,
                      :requested_version => options[:version] || :latest,
                      :local_changes => changes
              end
            end
          end

          @install_dir.prepare(name, options[:version] || 'latest')
          results[:install_dir] = @install_dir.target

          unless @local_tarball && @ignore_dependencies
            Puppet.notice _("Downloading from %{host} ...") % {
              host: mask_credentials(module_repository.host)
            }
          end

          if @ignore_dependencies
            graph = build_single_module_graph(name, version)
          else
            graph = build_dependency_graph(name, version)
          end

          unless forced?
            add_module_name_constraints_to_graph(graph)
          end

          installed_modules.each do |mod, release|
            mod = mod.tr('/', '-')
            next if mod == name

            version = release.version

            next if forced?

            # Since upgrading already installed modules can be troublesome,
            # we'll place constraints on the graph for each installed module,
            # locking it to upgrades within the same major version.
            installed_range = ">=#{version} #{version.major}.x"
            graph.add_constraint('installed', mod, installed_range) do |node|
              Puppet::Module.parse_range(installed_range).include? node.version
            end

            release.mod.dependencies.each do |dep|
              dep_name = dep['name'].tr('/', '-')

              range = dep['version_requirement']
              graph.add_constraint("#{mod} constraint", dep_name, range) do |node|
                Puppet::Module.parse_range(range).include? node.version
              end
            end
          end

          # Ensure that there is at least one candidate release available
          # for the target package.
          if graph.dependencies[name].empty?
            raise NoCandidateReleasesError, results.merge(:module_name => name, :source => module_repository.host, :requested_version => options[:version] || :latest)
          end

          begin
            Puppet.info _("Resolving dependencies ...")
            releases = SemanticPuppet::Dependency.resolve(graph)
          rescue SemanticPuppet::Dependency::UnsatisfiableGraph => e
            unsatisfied = nil

            if e.respond_to?(:unsatisfied) && e.unsatisfied
              constraints = {}
              # If the module we're installing satisfies all its
              # dependencies, but would break an already installed
              # module that depends on it, show what would break.
              if name == e.unsatisfied
                graph.constraints[name].each do |mod, range, _|
                  next unless mod.split.include?('constraint')

                  # If the user requested a specific version or range,
                  # only show the modules with non-intersecting ranges
                  if options[:version]
                    requested_range = SemanticPuppet::VersionRange.parse(options[:version])
                    constraint_range = SemanticPuppet::VersionRange.parse(range)

                    if requested_range.intersection(constraint_range) == SemanticPuppet::VersionRange::EMPTY_RANGE
                      constraints[mod.split.first] = range
                    end
                  else
                    constraints[mod.split.first] = range
                  end
                end

              # If the module fails to satisfy one of its
              # dependencies, show the unsatisfiable module
              else
                dep_constraints = graph.dependencies[name].max.constraints

                if dep_constraints.key?(e.unsatisfied)
                  unsatisfied_range = dep_constraints[e.unsatisfied].first[1]
                  constraints[e.unsatisfied] = unsatisfied_range
                end
              end

              installed_module = @environment.module_by_forge_name(e.unsatisfied.tr('-', '/'))
              current_version = installed_module.version if installed_module

              unsatisfied = {
                :name => e.unsatisfied,
                :constraints => constraints,
                :current_version => current_version
              } if constraints.any?
            end

            raise NoVersionsSatisfyError, results.merge(
              :requested_name => name,
              :requested_version => options[:version] || graph.dependencies[name].max.version.to_s,
              :unsatisfied => unsatisfied
            )
          end

          unless forced?
            # Check for module name conflicts.
            releases.each do |rel|
              installed_module = installed_modules_source.by_name[rel.name.split('-').last]
              next unless installed_module
              next if installed_module.has_metadata? && installed_module.forge_name.tr('/', '-') == rel.name

              if rel.name != name
                dependency = {
                  :name => rel.name,
                  :version => rel.version
                }
              end

              raise InstallConflictError,
                    :requested_module => name,
                    :requested_version => options[:version] || 'latest',
                    :dependency => dependency,
                    :directory => installed_module.path,
                    :metadata => installed_module.metadata
            end
          end

          Puppet.info _("Preparing to install ...")
          releases.each { |release| release.prepare }

          Puppet.notice _('Installing -- do not interrupt ...')
          releases.each do |release|
            installed = installed_modules[release.name]
            if forced? || installed.nil?
              release.install(Pathname.new(results[:install_dir]))
            else
              release.install(Pathname.new(installed.mod.modulepath))
            end
          end

          results[:result] = :success
          results[:installed_modules] = releases
          results[:graph] = [build_install_graph(releases.first, releases)]
        rescue ModuleToolError, ForgeError => err
          results[:error] = {
            :oneline => err.message,
            :multiline => err.multiline,
          }
        ensure
          results[:result] ||= :failure
        end

        results
      end

      private

      def module_repository
        @repo ||= Puppet::Forge.new(Puppet[:module_repository])
      end

      def local_tarball_source
        @tarball_source ||= begin
          Puppet::ModuleTool::LocalTarball.new(@name)
        rescue Puppet::Module::Error => e
          raise InvalidModuleError.new(@name, :action => @action, :error => e)
        end
      end

      def installed_modules_source
        @installed ||= Puppet::ModuleTool::InstalledModules.new(@environment)
      end

      def installed_modules
        installed_modules_source.modules
      end

      def build_single_module_graph(name, version)
        range = Puppet::Module.parse_range(version)
        graph = SemanticPuppet::Dependency::Graph.new(name => range)
        releases = SemanticPuppet::Dependency.fetch_releases(name)
        releases.each { |release| release.dependencies.clear }
        graph << releases
      end

      def build_dependency_graph(name, version)
        SemanticPuppet::Dependency.query(name => version)
      end

      def build_install_graph(release, installed, graphed = [])
        graphed << release
        dependencies = release.dependencies.values.map do |deps|
          dep = (deps & installed).first
          unless dep.nil? || graphed.include?(dep)
            build_install_graph(dep, installed, graphed)
          end
        end

        previous = installed_modules[release.name]
        previous = previous.version if previous
        return {
          :release => release,
          :name => release.name,
          :path => release.install_dir.to_s,
          :dependencies => dependencies.compact,
          :version => release.version,
          :previous_version => previous,
          :action => (previous.nil? || previous == release.version || forced? ? :install : :upgrade),
        }
      end

      include Puppet::ModuleTool::Shared

      # Return a Pathname object representing the path to the module
      # release package in the `Puppet.settings[:module_working_dir]`.
      def get_release_packages
        get_local_constraints

        if !forced? && @installed.include?(@module_name)
          raise AlreadyInstalledError,
                :module_name => @module_name,
                :installed_version => @installed[@module_name].first.version,
                :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
                :local_changes => Puppet::ModuleTool::Applications::Checksummer.run(@installed[@module_name].first.path)
        end

        if @ignore_dependencies && @source == :filesystem
          @urls   = {}
          @remote = { "#{@module_name}@#{@version}" => {} }
          @versions = {
            @module_name => [
              { :vstring => @version, :semver => SemanticPuppet::Version.parse(@version) }
            ]
          }
        else
          get_remote_constraints(@forge)
        end

        @graph = resolve_constraints({ @module_name => @version })
        @graph.first[:tarball] = @filename if @source == :filesystem
        resolve_install_conflicts(@graph) unless forced?

        # This clean call means we never "cache" the module we're installing, but this
        # is desired since module authors can easily rerelease modules different content but the same
        # version number, meaning someone with the old content cached will be very confused as to why
        # they can't get new content.
        # Long term we should just get rid of this caching behavior and cleanup downloaded modules after they install
        # but for now this is a quick fix to disable caching
        Puppet::Forge::Cache.clean
        download_tarballs(@graph, @graph.last[:path], @forge)
      end

      #
      # Resolve installation conflicts by checking if the requested module
      # or one of its dependencies conflicts with an installed module.
      #
      # Conflicts occur under the following conditions:
      #
      # When installing 'puppetlabs-foo' and an existing directory in the
      # target install path contains a 'foo' directory and we cannot determine
      # the "full name" of the installed module.
      #
      # When installing 'puppetlabs-foo' and 'pete-foo' is already installed.
      # This is considered a conflict because 'puppetlabs-foo' and 'pete-foo'
      # install into the same directory 'foo'.
      #
      def resolve_install_conflicts(graph, is_dependency = false)
        Puppet.debug("Resolving conflicts for #{graph.map { |n| n[:module] }.join(',')}")

        graph.each do |release|
          @environment.modules_by_path[options[:target_dir]].each do |mod|
            if mod.has_metadata?
              metadata = {
                :name => mod.forge_name.tr('/', '-'),
                :version => mod.version
              }
              next if release[:module] == metadata[:name]
            else
              metadata = nil
            end

            next unless release[:module] =~ /-#{mod.name}$/

            dependency_info = {
              :name => release[:module],
              :version => release[:version][:vstring]
            }
            dependency = is_dependency ? dependency_info : nil
            all_versions = @versions["#{@module_name}"].sort_by { |h| h[:semver] }
            versions = all_versions.select { |x| x[:semver].special == '' }
            versions = all_versions if versions.empty?
            latest_version = versions.last[:vstring]

            raise InstallConflictError,
                  :requested_module => @module_name,
                  :requested_version => @version || "latest: v#{latest_version}",
                  :dependency => dependency,
                  :directory => mod.path,
                  :metadata => metadata
          end

          deps = release[:dependencies]
          if deps && !deps.empty?
            resolve_install_conflicts(deps, true)
          end
        end
      end
    end
  end
end
