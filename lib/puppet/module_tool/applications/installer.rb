require 'open-uri'
require 'pathname'
require 'tmpdir'
require 'semver'
require 'puppet/forge'
require 'puppet/module_tool'

module Puppet::Module::Tool
  module Applications
    class Installer < Application
      class AlreadyInstalledError < Exception
        attr_accessor :module_name, :installed_version, :requested_version
        def initialize(options)
          @module_name       = options[:module_name      ]
          @installed_version = options[:installed_version].sub(/^(?=\d)/, 'v')
          @requested_version = options[:requested_version]
          @requested_version.sub!(/^(?=\d)/, 'v') if @requested_version.is_a? String
          super "'#{@module_name}' (#{@requested_version}) requested; '#{@module_name}' (#{@installed_version}) already installed"
        end

        def multiline
          <<-MSG.strip
Could not install module '#{@module_name}' (#{@requested_version}):
  Module '#{@module_name}' (#{@installed_version}) is already installed
    Use `puppet module upgrade` to install a different version
    Use `puppet module install --force` to re-install only this module
          MSG
        end
      end

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
        unless File.directory? options[:dir]
          msg = "Could not install module '#{@forge_name}' (#{@version || 'latest'}):\n"
          msg << "  Directory #{options[:dir]} does not exist"
          Puppet.err msg
          exit(1)
        end

        results = {
          :module_name    => @forge_name,
          :module_version => @version,
          :install_dir    => options[:dir],
        }

        begin
          cached_paths = get_release_packages

          unless @graph.empty?
            Puppet.notice 'Installing -- do not interrupt ...'
            cached_paths.each do |cache_path|
              Unpacker.run(cache_path, options)
            end
          end
        rescue AlreadyInstalledError => err
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
          @local = get_local_constraints

          if @installed.include? @forge_name
            raise AlreadyInstalledError,
              :module_name       => @forge_name,
              :installed_version => @installed[@forge_name],
              :requested_version => @version || (@conditions[@forge_name].empty? ? :latest : :best)
          end

          Puppet.notice "Downloading from #{Puppet::Forge.repository.uri} ..."
          @remote = get_remote_constraints

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
          end.inject(&:&)

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
            :dependencies => []
          }
        end.compact
        dependencies.each do |mod|
          deps = @remote["#{mod[:module]}@#{mod[:version][:vstring]}"]
          mod[:dependencies] = resolve_constraints(deps, mod[:module], seen)
        end unless options[:ignore_dependencies]
        return dependencies
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
end
