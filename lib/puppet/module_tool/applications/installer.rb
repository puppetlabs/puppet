require 'open-uri'
require 'pathname'
require 'tmpdir'
require 'puppet/forge'
require 'puppet/module_tool'

module Puppet::Module::Tool
  module Applications
    class Installer < Application

      def initialize(name, options = {})
        @environment = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @force = options[:force]

        if File.exist?(name)
          if File.directory?(name)
            # TODO Unify this handling with that of Unpacker#check_clobber!
            raise ArgumentError, "Module already installed: #{name}"
          end
          @filename = File.expand_path(name)
          @source = :filesystem
          parse_filename!
        else
          @source = :repository
          begin
            @author, @modname = Puppet::Module::Tool::username_and_modname_from(name)
          rescue ArgumentError
            raise "Could not install module with invalid name: #{name}"
          end
          @version = options[:version]
        end
        super(options)
      end

      def run
        cached_paths = get_release_packages

        cached_paths.each do |cache_path|
          Unpacker.run(cache_path, options)
        end

        cached_paths
      end

      private

      # Return a Pathname object representing the path to the module
      # release package in the `Puppet.settings[:module_working_dir]`.
      def get_release_packages
        cache_paths = nil
        case @source
        when :repository
          remote_dependency_info = Puppet::Forge::Forge.remote_dependency_info(@author, @modname, @version)
          install_list = resolve_remote_and_local_constraints(remote_dependency_info)
          install_list.map do |release|
            modname, version, file = release
            file
          end
          cache_paths = Puppet::Forge::Forge.get_release_packages_from_repository(install_list)
        when :filesystem
          cache_paths = [Puppet::Forge::Forge.get_release_package_from_filesystem(@filename)]
        end

        cache_paths
      end

      def find_latest_working_versions(name, versions, ancestors = [])
        return if ancestors.include?(name)
        ancestors << name

        if !versions[name] || versions[name].empty?
          # Raising here prevents us from backtracking and trying earlier
          # versions This means installations are less likely to succeed, but
          # should be more predictable If it's later decided that backtracking
          # is desired, replacing the raise with a `return false` should work
          raise RuntimeError, "No working versions for #{name}"
        end
        versions[name].sort_by {|v| v['version']}.reverse.each do |version|
          results = [[name, version['version'], version['file']]]
          return results if version['dependencies'].empty?
          version['dependencies'].each do |dep|
            dep_name, dep_req = dep
            working_versions = find_latest_working_versions(dep_name, versions, ancestors)
            results += working_versions if working_versions
          end
          return results
        end
        false
      end

      def resolve_remote_and_local_constraints(remote_dependency_info)
        warnings = remote_dependency_info.delete('_warnings')
        warnings.each do |warning|
          Puppet.warning warning
        end if warnings

        remote_dependency_info.each do |mod_name, versions|
          resolve_already_existing_module_constraints(mod_name, versions)
          resolve_local_constraints(mod_name, versions)
        end

        mod_download_list = find_latest_working_versions("#{@author}/#{@modname}", remote_dependency_info)
        skip_already_installed_modules(mod_download_list)
        skip_upgrades_with_local_changes(mod_download_list)

        mod_download_list
      end

      def skip_already_installed_modules(mod_download_list)
        local_modules = @environment.modules
        already_installed_mods = local_modules.inject({}) do |mods, mod|
          if mod.forge_name
            mods["#{mod.forge_name}@#{mod.version}"] = true
          end
          mods
        end

        mod_download_list.delete_if do |mod|
          forge_name, version, file = mod

          already_installed = already_installed_mods["#{forge_name}@#{version}"]
          if already_installed
            Puppet.debug "Not downloading #{forge_name} (#{version}) because it's already installed"
          end
          already_installed
        end
      end

      def skip_upgrades_with_local_changes(mod_download_list)
        mod_download_list.each do |mod|
          forge_name, version, file = mod

          if local_mod = @environment.module_by_forge_name(forge_name)
            if local_mod.has_local_changes?
              msg = "Module #{forge_name} (#{version}) needs to be installed to satisfy contraints, "
              msg << "but can't be because it has local changes"
              raise RuntimeError, msg
            end
          end
        end
      end

      def resolve_local_constraints(forge_name, versions)
        local_deps = @environment.module_requirements
        versions.delete_if do |version_info|
          semver = SemVer.new(version_info['version'])
          local_deps[forge_name] and local_deps[forge_name].any? do |req|
            req_name, version_req = req
            equality, local_ver = version_req.split(/\s/)
            !(semver.send(equality, SemVer.new(local_ver)))
          end
        end
      end

      def resolve_already_existing_module_constraints(forge_name, versions)
        author_name, mod_name = forge_name.split('/')
        existing_mod = @environment.module(mod_name)
        if existing_mod
          unless existing_mod.has_metadata?
            raise RuntimeError, "A local version of the #{mod_name} module exists but has no metadata"
          end
          if existing_mod.forge_name != forge_name
            raise RuntimeError, "A local version of the #{mod_name} module exists but has a different name (#{existing_mod.forge_name})"
          end
          if !existing_mod.version || existing_mod.version.empty?
            raise RuntimeError, "A local version of the #{mod_name} module exists without version info"
          end
          begin
            SemVer.new(existing_mod.version)
          rescue => e
            raise RuntimeError,
              "A local version of the #{mod_name} module declares a non semantic version (#{existing_mod.version})"
          end
          if versions.map {|v| v['version']}.include? existing_mod.version
            versions.delete_if {|version_info| version_info['version'] != existing_mod.version}
          end
        end
      end
    end
  end
end
