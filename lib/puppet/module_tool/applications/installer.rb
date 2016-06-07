require 'open-uri'
require 'pathname'
require 'fileutils'
require 'tmpdir'

require 'puppet/forge'
require 'puppet/module_tool'
require 'puppet/module_tool/shared_behaviors'
require 'puppet/module_tool/install_directory'
require 'puppet/module_tool/local_tarball'
require 'puppet/module_tool/installed_modules'

module Puppet::ModuleTool
  module Applications
    class Installer < Application

      include Puppet::ModuleTool::Errors
      include Puppet::Forge::Errors

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
          Semantic::Dependency.add_source(local_tarball_source)

          # If we're operating on a local tarball and ignoring dependencies, we
          # don't need to search any additional sources.  This will cut down on
          # unnecessary network traffic.
          unless @ignore_dependencies
            Semantic::Dependency.add_source(installed_modules_source)
            Semantic::Dependency.add_source(module_repository)
          end

        else
          Semantic::Dependency.add_source(installed_modules_source) unless forced?
          Semantic::Dependency.add_source(module_repository)
        end
      end

      def run
        name = @name.tr('/', '-')
        version = options[:version] || '>= 0.0.0'

        results = { :action => :install, :module_name => name, :module_version => version }

        begin
          if installed_module = installed_modules[name]
            unless forced?
              if Semantic::VersionRange.parse(version).include? installed_module.version
                results[:result] = :noop
                results[:version] = installed_module.version
                return results
              else
                changes = Checksummer.run(installed_modules[name].mod.path) rescue []
                raise AlreadyInstalledError,
                  :module_name       => name,
                  :installed_version => installed_modules[name].version,
                  :requested_version => options[:version] || :latest,
                  :local_changes     => changes
              end
            end
          end

          @install_dir.prepare(name, options[:version] || 'latest')
          results[:install_dir] = @install_dir.target

          unless @local_tarball && @ignore_dependencies
            Puppet.notice "Downloading from #{module_repository.host} ..."
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

            unless forced?
              # Since upgrading already installed modules can be troublesome,
              # we'll place constraints on the graph for each installed module,
              # locking it to upgrades within the same major version.
              installed_range = ">=#{version} #{version.major}.x"
              graph.add_constraint('installed', mod, installed_range) do |node|
                Semantic::VersionRange.parse(installed_range).include? node.version
              end

              release.mod.dependencies.each do |dep|
                dep_name = dep['name'].tr('/', '-')

                range = dep['version_requirement']
                graph.add_constraint("#{mod} constraint", dep_name, range) do |node|
                  Semantic::VersionRange.parse(range).include? node.version
                end
              end
            end
          end

          # Ensure that there is at least one candidate release available
          # for the target package.
          if graph.dependencies[name].empty?
            raise NoCandidateReleasesError, results.merge(:module_name => name, :source => module_repository.host, :requested_version => options[:version] || :latest)
          end

          begin
            Puppet.info "Resolving dependencies ..."
            releases = Semantic::Dependency.resolve(graph)
          rescue Semantic::Dependency::UnsatisfiableGraph
            raise NoVersionsSatisfyError, results.merge(:requested_name => name)
          end

          unless forced?
            # Check for module name conflicts.
            releases.each do |rel|
              if installed_module = installed_modules_source.by_name[rel.name.split('-').last]
                next if installed_module.has_metadata? && installed_module.forge_name.tr('/', '-') == rel.name

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
                  :directory         => installed_module.path,
                  :metadata          => installed_module.metadata
              end
            end
          end

          Puppet.info "Preparing to install ..."
          releases.each { |release| release.prepare }

          Puppet.notice 'Installing -- do not interrupt ...'
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
          results[:graph] = [ build_install_graph(releases.first, releases) ]

        rescue ModuleToolError, ForgeError => err
          results[:error] = {
            :oneline   => err.message,
            :multiline => err.multiline,
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

      def local_tarball_source
        @tarball_source ||= begin
          Puppet::ModuleTool::LocalTarball.new(@name)
        rescue Puppet::Module::Error => e
          raise InvalidModuleError.new(@name, :action => @action, :error  => e)
        end
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
          :release          => release,
          :name             => release.name,
          :path             => release.install_dir.to_s,
          :dependencies     => dependencies.compact,
          :version          => release.version,
          :previous_version => previous,
          :action           => (previous.nil? || previous == release.version || forced? ? :install : :upgrade),
        }
      end

      include Puppet::ModuleTool::Shared

      # Return a Pathname object representing the path to the module
      # release package in the `Puppet.settings[:module_working_dir]`.
      def get_release_packages
        get_local_constraints

        if !forced? && @installed.include?(@module_name)
          raise AlreadyInstalledError,
            :module_name       => @module_name,
            :installed_version => @installed[@module_name].first.version,
            :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
            :local_changes     => Puppet::ModuleTool::Applications::Checksummer.run(@installed[@module_name].first.path)
        end

        if @ignore_dependencies && @source == :filesystem
          @urls   = {}
          @remote = { "#{@module_name}@#{@version}" => { } }
          @versions = {
            @module_name => [
              { :vstring => @version, :semver => SemVer.new(@version) }
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
        Puppet.debug("Resolving conflicts for #{graph.map {|n| n[:module]}.join(',')}")

        graph.each do |release|
          @environment.modules_by_path[options[:target_dir]].each do |mod|
            if mod.has_metadata?
              metadata = {
                :name    => mod.forge_name.gsub('/', '-'),
                :version => mod.version
              }
              next if release[:module] == metadata[:name]
            else
              metadata = nil
            end

            if release[:module] =~ /-#{mod.name}$/
              dependency_info = {
                :name    => release[:module],
                :version => release[:version][:vstring]
              }
              dependency = is_dependency ? dependency_info : nil
              all_versions = @versions["#{@module_name}"].sort_by { |h| h[:semver] }
              versions = all_versions.select { |x| x[:semver].special == '' }
              versions = all_versions if versions.empty?
              latest_version = versions.last[:vstring]

              raise InstallConflictError,
                :requested_module  => @module_name,
                :requested_version => @version || "latest: v#{latest_version}",
                :dependency        => dependency,
                :directory         => mod.path,
                :metadata          => metadata
            end
          end

          deps = release[:dependencies]
          if deps && !deps.empty?
            resolve_install_conflicts(deps, true)
          end
        end
      end

      #
      # Check if a file is a vaild module package.
      # ---
      # FIXME: Checking for a valid module package should be more robust and
      # use the actual metadata contained in the package. 03132012 - Hightower
      # +++
      #
      def is_module_package?(name)
        filename = File.expand_path(name)
        filename =~ /.tar.gz$/
      end
    end
  end
end
