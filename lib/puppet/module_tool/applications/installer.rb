require 'open-uri'
require 'pathname'
require 'fileutils'
require 'tmpdir'
require 'semver'
require 'puppet/forge'
require 'puppet/module_tool'
require 'puppet/module_tool/shared_behaviors'
require 'puppet/module_tool/install_directory'

module Puppet::ModuleTool
  module Applications
    class Installer < Application

      include Puppet::ModuleTool::Errors
      include Puppet::Forge::Errors

      def initialize(name, forge, install_dir, options = {})
        super(options)
        @action              = :install
        @environment         = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @force               = options[:force]
        @ignore_dependencies = options[:force] || options[:ignore_dependencies]
        @name                = name
        @forge               = forge
        @install_dir         = install_dir
      end

      def run
        results = {}
        begin
          if is_module_package?(@name)
            @source = :filesystem
            @filename = File.expand_path(@name)
            raise MissingPackageError, :requested_package => @filename unless File.exist?(@filename)

            parsed = parse_filename(@filename)
            @module_name = parsed[:module_name]
            @version     = parsed[:version]
          else
            @source = :repository
            @module_name = @name.gsub('/', '-')
            @version = options[:version]
          end

          results = {
            :module_name    => @module_name,
            :module_version => @version,
            :install_dir    => options[:target_dir],
          }

          @install_dir.prepare(@module_name, @version || 'latest')

          cached_paths = get_release_packages

          unless @graph.empty?
            Puppet.notice 'Installing -- do not interrupt ...'
            cached_paths.each do |hash|
              hash.each do |dir, path|
                Unpacker.new(path, @options.merge(:target_dir => dir)).run
              end
            end
          end
        rescue ModuleToolError, ForgeError => err
          results[:error] = {
            :oneline   => err.message,
            :multiline => err.multiline,
          }
        else
          results[:result] = :success
          results[:installed_modules] = @graph
        ensure
          results[:result] ||= :failure
        end

        results
      end

      private

      include Puppet::ModuleTool::Shared

      # Return a Pathname object representing the path to the module
      # release package in the `Puppet.settings[:module_working_dir]`.
      def get_release_packages
        get_local_constraints

        if !@force && @installed.include?(@module_name)

          raise AlreadyInstalledError,
            :module_name       => @module_name,
            :installed_version => @installed[@module_name].first.version,
            :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
            :local_changes     => @installed[@module_name].first.local_changes
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
        resolve_install_conflicts(@graph) unless @force

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

            resolve_install_conflicts(release[:dependencies], true)
          end
        end
      end

      #
      # Check if a file is a vaild module package.
      # ---
      # FIXME: Checking for a valid module package should be more robust and
      # use the acutal metadata contained in the package. 03132012 - Hightower
      # +++
      #
      def is_module_package?(name)
        filename = File.expand_path(name)
        filename =~ /.tar.gz$/
      end
    end
  end
end
