require 'open-uri'
require 'pathname'
require 'tmpdir'
require 'semver'
require 'puppet/forge'
require 'puppet/module_tool'

module Puppet::Module::Tool
  module Applications
    class Installer < Application
      require 'puppet/module_tool/applications/installer/exceptions'

      def initialize(name, options = {})
        @environment = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @force = options[:force]
        @ignore_dependencies = @force || options[:ignore_dependencies]

        if is_package?(name)
          @filename = File.expand_path(name)
          @source = :filesystem

          @forge_name, @author,  @modname, @version = parse_filename!
          @urls = { }
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

        results = {
          :module_name    => @forge_name,
          :module_version => @version,
          :install_dir    => options[:dir],
        }

        begin
          unless File.directory? options[:dir]
            msg = "Could not install module '#{@forge_name}' (#{@version || 'latest'})\n"
            msg << "  Directory #{options[:dir]} does not exist"
            Puppet.err msg
            exit(1)
          end

          if @source == :filesystem && !File.exist?(@filename)
            raise MissingPackageError,
              :requested_package => @filename
          end

          cached_paths = get_release_packages
          unless @graph.empty?
            Puppet.notice 'Installing -- do not interrupt ...'
            cached_paths.each do |cache_path|
              Unpacker.run(cache_path, options)
            end
          end
        rescue AlreadyInstalledError, NoVersionSatisfyError, MissingPackageError,
               InvalidDependencyCycleError, InstallConflictError => err
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
            next unless mod.has_metadata?
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
        @local = get_local_constraints

        if @force
          options[:ignore_dependencies] = true
        elsif @installed.include? @forge_name
          raise AlreadyInstalledError,
            :module_name       => @forge_name,
            :installed_version => @installed[@forge_name],
            :requested_version => @version || (@conditions[@forge_name].empty? ? :latest : :best)
        end

        if options[:ignore_dependencies] && @source == :filesystem
          @remote = {
            "#{@forge_name}@#{@version}" => { }
          }
          @versions = {
            @forge_name => [{:vstring => @version, :semver => SemVer.new(@version)}]
          }
        else
          Puppet.notice "Downloading from #{Puppet::Forge.repository.uri} ..."
          @remote = get_remote_constraints
        end

        @graph = resolve_constraints({ @forge_name => @version })
        resolve_install_conflicts(@graph) unless @force
        download_tarballs(@graph)
      end

      def resolve_constraints(dependencies, source = [{:name => :you}], seen = {})
        dependencies = dependencies.map do |mod, range|
          action = :install

          source.last[:dependency] = range

          @conditions[mod] << {
            :module     => source.last[:name],
            :version    => source.last[:version],
            :dependency => range
          }

          range = (@conditions[mod]).map do |r|
            SemVer[r[:dependency]] rescue SemVer['>= 0.0.0']
          end.inject(&:&)

          best_requested_versions = @versions["#{@forge_name}"].sort_by { |h| h[:semver] }

          if seen.include? mod
            next if range === seen[mod][:semver]
            raise InvalidDependencyCycleError,
              :module_name       => mod,
              :source            => source,
              :version           => 'v1.0.0',
              :requested_module  => @forge_name,
              :requested_version => @version || (best_requested_versions.empty? ? 'latest' : "latest: #{best_requested_versions.last[:semver]}"),
              :conditions        => @conditions
          end

          if @installed[mod] && ! @force
            next if range === SemVer.new(@installed[mod])
            action = :upgrade
            # TODO: Update invalid installed dependencies.
            # TODO: Update conditions when upgrading a local module.
          end

          valid_versions = @versions["#{mod}"].select { |h| range === h[:semver] } \
                                              .sort_by { |h| h[:semver] }

          unless version = valid_versions.last or @force

            raise NoVersionSatisfyError,
              :module_name       => mod,
              :source            => source.last,
              :version           => valid_versions.empty? ? 'best' : "best: #{valid_versions.last}",
              :requested_module  => @forge_name,
              :requested_version => @version || (best_requested_versions.empty? ? 'best' : "best: #{best_requested_versions.last[:semver]}"),
              :conditions        => @conditions
          end

          seen[mod] = version

          # Get the best available version of the requested module and install
          # it and ignore dependencies.
          if @force
            mod     = @forge_name
            version = @versions["#{@forge_name}"].sort_by { |h| h[:semver] }.last
          end

          {
            :module => mod,
            :version => version,
            :action => action,
            :previous_version => @installed[mod],
            :file => @urls["#{mod}@#{version[:vstring]}"],
            :path => @options[:dir],
            :dependencies => []
          }
        end.compact
        dependencies.each do |mod|
          deps = @remote["#{mod[:module]}@#{mod[:version][:vstring]}"]
          mod[:dependencies] = resolve_constraints(deps, source + [{ :name => mod[:module], :version => mod[:version][:vstring] }], seen)
        end unless options[:ignore_dependencies]
        return dependencies
      end

      def download_tarballs(graph)
        graph.map do |release|
          cache_path = nil
          begin
            if release[:module] == @forge_name && @source == :filesystem
              cache_path = Pathname(@filename)
            else
              cache_path = Puppet::Forge.repository.retrieve(release[:file])
            end
          rescue OpenURI::HTTPError => e
            raise RuntimeError, "Could not download module: #{e.message}"
          end
          [ cache_path, *download_tarballs(release[:dependencies]) ]
        end.flatten
      end

      def resolve_install_conflicts(graph, is_dependency = false)
        graph.each do |release|
          @environment.modules_by_path[options[:dir]].each do |mod|
            
            if mod.has_metadata?
              metadata = {
                :name    => mod.forge_name.gsub('/', '-'),
                :version => mod.version
              }
              match = release[:module] =~ /#{metadata[:name]}/
              next if match == 0
            else
              metadata = nil
            end

            if release[:module] =~ /#{mod.name}/
              dependency_info = {
                :name    => release[:module],
                :version => release[:version][:vstring]
              }
              dependency = is_dependency ? dependency_info : nil
              latest_version = @versions["#{@forge_name}"].sort_by { |h| h[:semver] }.last[:vstring]

              raise InstallConflictError,
                :requested_module  => @forge_name,
                :requested_version => @version || "latest: v#{latest_version}",
                :dependency        => dependency,
                :directory         => mod.path,
                :metadata          => metadata
            end

            resolve_install_conflicts(release[:dependencies], true)
          end
        end
      end

      def is_package?(name)
        filename = File.expand_path(name)
        filename =~ /.tar.gz$/
      end
    end
  end
end
