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

      def initialize(name, forge, options = {})
        super(options)
        @name                = name
        @forge               = forge
        @action              = :install
        @environment         = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @force               = options[:force]
        @ignore_dependencies = @force || options[:ignore_dependencies]
      end

      def run
        results = {
          :install_dir => options[:target_dir]
        }

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

          Puppet.notice "Preparing to install into #{options[:target_dir]} ..."
          # prepare (create) the target directory
          Puppet::ModuleTool::InstallDirectory.
             new(Pathname.new(options[:target_dir])).
             prepare(@module_name, @version || 'latest')

          # scan already installed module releases
          get_local_constraints

          if !@force && previous = @installed[@module_name].first
            raise AlreadyInstalledError,
              :module_name       => @module_name,
              :installed_version => previous[:version],
              :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
              :local_changes     => has_local_changes?(previous)
          end

          # get the module releases to install / upgrade
          cached_paths = get_release_packages(metadata)

          # install them
          Puppet.notice 'Installing -- do not interrupt ...'
          cached_paths.each do |hash|
            hash.each do |dir, path|
              Unpacker.new(path, @options.merge(:target_dir => dir)).run
            end
          end
        rescue => err
          results[:error] = {
            :oneline => err.message,
            :multiline => err.respond_to?(:multiline) ? err.multiline : [err.to_s, err.backtrace].join("\n")
          }
        else
          results[:affected_modules] = @graph
          results[:result] = :success
          # for backward compatibility
          results[:installed_modules] = results[:affected_modules]
        ensure
          results[:result] ||= :failure
        end

        results
      end

      private

      include Puppet::ModuleTool::Shared
    end
  end
end
