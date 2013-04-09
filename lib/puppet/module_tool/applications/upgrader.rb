module Puppet::ModuleTool
  module Applications
    class Upgrader < Application

      include Puppet::ModuleTool::Errors

      def initialize(name, forge, options)
        super(options)
        @name                = name
        @forge               = forge
        @action              = :upgrade
        @environment         = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @force               = options[:force]
        @ignore_dependencies = @froce || options[:ignore_dependencies]
      end

      def run
        results = {
          :install_dir => options[:target_dir]
        }
        # for backward compatibility
        results[:base_dir] = results[:install_dir]

        begin
          if metadata = read_module_package_metadata(@name)
            @module_name = metadata['name']
            @version     = metadata['version']
          else
            @module_name = @name.tr('/', '-')
            @version = options[:version]
          end

          results[:module_name] = @module_name
          results[:module_version] = @version

          Puppet.notice "Preparing to upgrade '#{@module_name}' ..."

          # scan already installed module releases
          get_local_constraints

          if @installed[@module_name].length > 1
            raise MultipleInstalledError,
              :action            => :upgrade,
              :module_name       => @module_name,
              :installed_modules => @installed[@module_name].sort_by { |release|
                @environment.modulepath.index(release[:module].modulepath)
              }.map{ |release| release[:module] }
          elsif @installed[@module_name].empty?
            raise NotInstalledError,
              :action            => :upgrade,
              :module_name       => @module_name
          end

          previous = @installed[@module_name].first
          Puppet.notice "Found '#{@module_name}' (" <<
            colorize(:cyan, previous[:version] ? previous[:version].sub(/^(?=\d)/, 'v') : '???') <<
            ") in #{previous[:module].modulepath} ..."

          if !@force && has_local_changes?(previous)
            raise LocalChangesError,
              :action => :upgrade,
              :module_name => @module_name,
              :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
              :installed_version => previous[:version]
          end

          # get the module releases to install / upgrade
          cached_paths = get_release_packages(metadata)

          upgrade = @graph.first[:release]
          if !@force && (upgrade[:semver] == previous[:semver] || !@version && upgrade[:semver] < previous[:semver])
            raise VersionAlreadyInstalledError,
              :module_name       => @module_name,
              :installed_version => previous[:version],
              :requested_version => @version || upgrade[:version],
              :specified_version => @version,
              :conditions        => @conditions[@module_name]
          end

          Puppet.notice 'Upgrading -- do not interrupt ...'
          cached_paths.each do |hash|
            hash.each do |dir, path|
              Unpacker.new(path, @options.merge(:target_dir => dir)).run
            end
          end
        rescue VersionAlreadyInstalledError => err
          results[:error] = {
            :oneline   => err.message,
            :multiline => err.multiline
          }
          results[:result] = :noop
        rescue => err
          results[:error] = {
            :oneline => err.message,
            :multiline => err.respond_to?(:multiline) ? err.multiline : [err.to_s, err.backtrace].join("\n")
          }
        else
          results[:affected_modules] = @graph
          results[:install_dir] = options[:target_dir]
          results[:result] = :success
        ensure
          results[:result] ||= :failure
        end

        return results
      end

      private

      include Puppet::ModuleTool::Shared
    end
  end
end
