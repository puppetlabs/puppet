require 'open-uri'
require 'pathname'
require 'tmpdir'
require 'semver'
require 'puppet/forge'
require 'puppet/module_tool'
require 'puppet/module_tool/shared_behaviors'

module Puppet::Module::Tool
  module Applications
    class Installer < Application
      require 'puppet/module_tool/applications/installer/exceptions'

      def initialize(name, options = {})
        @action              = :install
        @environment         = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @force               = options[:force]
        @ignore_dependencies = options[:force] || options[:ignore_dependencies]
        @name                = name
        super(options)
      end

      def run
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
            :install_dir    => options[:dir],
          }

          unless File.directory? options[:dir]
            msg = "Could not install module '#{@module_name}' (#{@version || 'latest'})\n"
            msg << "  Directory #{options[:dir]} does not exist"
            Puppet.err msg
            exit(1)
          end

          cached_paths = get_release_packages

          unless @graph.empty?
            Puppet.notice 'Installing -- do not interrupt ...'
            cached_paths.each do |hash|
              hash.each do |dir, path|
                Unpacker.new(path, @options.merge(:dir => dir)).run
              end
            end
          end
        rescue AlreadyInstalledError, NoVersionsSatisfyError, MissingPackageError,
               InvalidDependencyCycleError, InstallConflictError => err
          results[:error] = {
            :oneline   => err.message,
            :multiline => err.multiline,
          }
        rescue => err
          results[:error] = {
            :oneline => err.message,
            :multiline => [err.message, err.backtrace].join("\n")
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

      include Puppet::Module::Tool::Shared

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
          @remote = { "#{@module_name}@#{@version}" => { } }
          @versions = {
            @module_name => [
              { :vstring => @version, :semver => SemVer.new(@version) }
            ]
          }
        else
          get_remote_constraints
        end

        @graph = resolve_constraints({ @module_name => @version })
        @graph.first[:tarball] = @filename if @source == :filesystem
        resolve_install_conflicts(@graph) unless @force
        download_tarballs(@graph, @graph.last[:path])
      end

      def resolve_install_conflicts(graph, is_dependency = false)
        graph.each do |release|
          @environment.modules_by_path[options[:dir]].each do |mod|
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
              latest_version = @versions["#{@module_name}"].sort_by { |h| h[:semver] }.last[:vstring]

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

      def is_module_package?(name)
        filename = File.expand_path(name)
        filename =~ /.tar.gz$/
      end
    end
  end
end
