require 'open-uri'
require 'pathname'
require 'tmpdir'
require 'semver'
require 'puppet/forge'
require 'puppet/module_tool'

module Puppet::Module::Tool
  module Applications
    class Installer < Application

      def initialize(name, options = {})
        @environment = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @force = options[:force]
        @ignore_dependencies = options[:ignore_dependencies]

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
            @forge_name = name.gsub('/', '-')
            @author, @modname = Puppet::Module::Tool::username_and_modname_from(name)
          rescue ArgumentError
            raise "Could not install module with invalid name: #{name}"
          end
          @version = options[:version]
          @urls = { }
        end
        super(options)
      end

      def run
        cached_paths = get_release_packages

        unless @graph.empty?
          Puppet.notice 'Unpacking -- do not interrupt ...'
          cached_paths.each do |cache_path|
            Unpacker.run(cache_path, options)
          end
        end

        @graph
      end

      def skip_upgrades_with_local_changes(mod_download_list)
        mod_download_list.each do |mod|
          forge_name, version, file = mod

          if local_mod = @environment.module_by_forge_name(forge_name)
            if local_mod.has_local_changes?
              msg = "Changes in these files #{local_mod.local_changes.join(' ')}\n"
              if @force
                msg << "Overwriting module #{forge_name} (#{version}) despite local changes because of force flag"
                Puppet.warning msg
              else
                msg << "Module #{forge_name} (#{version}) needs to be installed to satisfy contraints, "
                msg << "but can't be because it has local changes"
                raise RuntimeError, msg
              end
            end
          end
        end
      end

      private

      def get_local_constraints
        @conditions = Hash.new { |h,k| h[k] = [] }
        @installed = { }
        @environment.modules.inject(Hash.new { |h,k| h[k] = { } }) do |deps, mod|
          deps.tap do
            mod_name = mod.forge_name.gsub('/', '-')
            @installed[mod_name] = mod.version
            d = deps["#{mod_name}@#{mod.version}"]
            mod.dependencies.each do |hash|
              name, conditions = hash['name'], hash['version_requirement']
              name = name.gsub('/', '-')
              d[name] = conditions
              @conditions[name] << {
                :module => mod_name,
                :version => mod.version,
                :dependency => conditions
              }
            end
          end
        end
      end

      def get_remote_constraints
        @versions = Hash.new { |h,k| h[k] = [] }
        info = Puppet::Forge.remote_dependency_info(@author, @modname, @version)
        info.inject(Hash.new { |h,k| h[k] = { } }) do |deps, pair|
          deps.tap do
            mod_name, releases = pair
            mod_name = mod_name.gsub('/', '-')
            releases.each do |rel|
              semver = SemVer.new(rel['version'] || '0.0.0') rescue SemVer.MIN
              @versions[mod_name] << {
                :vstring => rel['version'],
                :semver => semver
              }
              @urls["#{mod_name}@#{rel['version']}"] = rel['file']
              d = deps["#{mod_name}@#{rel['version']}"]
              (rel['dependencies'] || []).each do |name, conditions|
                d[name.gsub('/', '-')] = conditions
              end
            end
          end
        end
      end

      # Return a Pathname object representing the path to the module
      # release package in the `Puppet.settings[:module_working_dir]`.
      def get_release_packages
        cache_paths = nil
        case @source
        when :repository
          Puppet.notice "Downloading from #{Puppet::Forge.repository.uri} ..."
          @local = get_local_constraints
          @remote = get_remote_constraints

          raise "Already installed!" if @installed.include? @forge_name

          @graph = resolve_constraints({ @forge_name => @version || '>= 0.0.0' })
          return download_tarballs(@graph)
        when :filesystem
          cache_paths = [Puppet::Forge.get_release_package_from_filesystem(@filename)]
        end

        cache_paths
      end

      def resolve_constraints(dependencies, source = :you, seen = {})
        dependencies = dependencies.map do |mod, range|
          action = :install

          range = (@conditions[mod] + [ { :dependency => range } ]).map do |r|
            SemVer[r[:dependency]] rescue SemVer['>= 0.0.0']
          end.inject(:&)

          if seen.include? mod
            next if range === seen[mod][:semver]
            raise "Invalid dependency cycle."
          end

          if @installed[mod]
            next if range === SemVer.new(@installed[mod])
            action = :upgrade
            # TODO: Update invalid installed dependencies.
            # TODO: Update conditions when upgrading a local module.
          end

          valid_versions = @versions["#{mod}"].select { |h| range === h[:semver] } \
                                              .sort_by { |h| h[:semver] }

          raise "No versions satisfy!" unless version = valid_versions.last

          seen[mod] = version
          @conditions[mod] << { source => range }

          {
            :module => mod,
            :version => version,
            :action => action,
            :previous_version => @installed[mod],
            :file => @urls["#{mod}@#{version[:vstring]}"],
          }
        end.compact
        dependencies.each do |mod|
          deps = @remote["#{mod[:module]}@#{mod[:version][:vstring]}"]
          mod[:dependencies] = resolve_constraints(deps, mod[:module], seen)
        end
      end

      def download_tarballs(graph)
        graph.map do |release|
          cache_path = nil
          begin
            cache_path = Puppet::Forge.repository.retrieve(release[:file])
          rescue OpenURI::HTTPError => e
            raise RuntimeError, "Could not download module: #{e.message}"
          end
          [ cache_path, *download_tarballs(release[:dependencies]) ]
        end.flatten
      end
    end
  end

  #     def ignore_dependencies(remote_dependency_info)
  #       remote_dependency_info.delete_if do |mod, versions|
  #         mod != @forge_name
  #       end
  #       remote_dependency_info[@forge_name].each do |release|
  #         release['dependencies'] = []
  #       end
  #       remote_dependency_info
  #     end
  # 
  #     def find_latest_working_versions(name, versions, ancestors = [])
  #       return if ancestors.include?(name)
  #       ancestors << name
  # 
  #       if !versions[name] || versions[name].empty?
  #         if @force
  #           Puppet.warning "No working versions for #{name}, skipping because of force"
  #           return
  #         else
  #           raise RuntimeError, "No working versions for #{name}"
  #         end
  #       end
  #       versions[name].sort_by {|v| v['version']}.reverse.each do |version|
  #         results = [[name, version['version'], version['file']]]
  #         return results if version['dependencies'].empty?
  #         version['dependencies'].each do |dep|
  #           dep_name, dep_req = dep
  #           working_versions = find_latest_working_versions(dep_name, versions, ancestors)
  #           results += working_versions if working_versions
  #         end
  #         return results
  #       end
  #       false
  #     end
  # 
  #     def resolve_remote_and_local_constraints(remote_dependency_info)
  #       warnings = remote_dependency_info.delete('_warnings')
  #       warnings.each do |warning|
  #         Puppet.warning warning
  #       end if warnings
  # 
  #       remote_dependency_info.each do |mod_name, versions|
  #         resolve_already_existing_module_constraints(mod_name, versions)
  #         resolve_local_constraints(mod_name, versions)
  #       end
  # 
  #       mod_download_list = find_latest_working_versions("#{@author}/#{@modname}", remote_dependency_info)
  #       skip_already_installed_modules(mod_download_list)
  #       skip_upgrades_with_local_changes(mod_download_list)
  # 
  #       mod_download_list
  #     end
  # 
  #     def skip_already_installed_modules(mod_download_list)
  #       local_modules = @environment.modules
  #       already_installed_mods = local_modules.inject({}) do |mods, mod|
  #         if mod.forge_name
  #           mods["#{mod.forge_name}@#{mod.version}"] = true
  #         end
  #         mods
  #       end
  # 
  #       mod_download_list.delete_if do |mod|
  #         forge_name, version, file = mod
  # 
  #         already_installed = already_installed_mods["#{forge_name}@#{version}"]
  #         if already_installed
  #           if @force
  #             already_installed = false
  #             Puppet.warning "Installing #{forge_name} (#{version}) even though it's already installed because of the force flag"
  #           else
  #             Puppet.info "Not downloading #{forge_name} (#{version}) because it's already installed"
  #           end
  #         end
  #         already_installed
  #       end
  #     end
  # 
  #     def skip_upgrades_with_local_changes(mod_download_list)
  #       mod_download_list.each do |mod|
  #         forge_name, version, file = mod
  # 
  #         if local_mod = @environment.module_by_forge_name(forge_name)
  #           if local_mod.has_local_changes?
  #             if @force
  #               msg = "Overwriting module #{forge_name} (#{version}) despite local changes because of force flag"
  #               Puppet.warning msg
  #             else
  #               msg = "Module #{forge_name} (#{version}) needs to be installed to satisfy contraints, "
  #               msg << "but can't be because it has local changes"
  #               raise RuntimeError, msg
  #             end
  #           end
  #         end
  #       end
  #     end
  # 
  #     def resolve_local_constraints(forge_name, versions)
  #       local_deps = @environment.module_requirements
  #       versions.delete_if do |version_info|
  #         remote_ver = SemVer.new(version_info['version'])
  #         local_deps[forge_name] and local_deps[forge_name].any? do |req|
  #           req_name    = req['name']
  #           version_req = req['version_requirement']
  #           equality, local_ver = version_req.split(/\s/)
  #           local_ver_range = SemVer[version_req]
  #           !(local_ver_range.include? remote_ver)
  #         end
  #       end
  #     end
  # 
  #     def resolve_already_existing_module_constraints(forge_name, versions)
  #       author_name, mod_name = forge_name.split('/')
  #       existing_mod = @environment.module(mod_name)
  #       if existing_mod
  #         unless existing_mod.has_metadata?
  #           raise RuntimeError, "A local version of the #{mod_name} module exists but has no metadata"
  #         end
  #         if existing_mod.forge_name != forge_name
  #           raise RuntimeError, "A local version of the #{mod_name} module exists but has a different name (#{existing_mod.forge_name})"
  #         end
  #         if !existing_mod.version || existing_mod.version.empty?
  #           raise RuntimeError, "A local version of the #{mod_name} module exists without version info"
  #         end
  #         begin
  #           SemVer.new(existing_mod.version)
  #         rescue => e
  #           raise RuntimeError,
  #             "A local version of the #{mod_name} module declares a non semantic version (#{existing_mod.version})"
  #         end
  #         if versions.map {|v| v['version']}.include? existing_mod.version
  #           versions.delete_if {|version_info| version_info['version'] != existing_mod.version}
  #         end
  #       end
  #     end
  #   end
  # end
end
