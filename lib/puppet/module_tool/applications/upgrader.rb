module Puppet::Module::Tool
  module Applications
    class Upgrader
      class UpgradeError < StandardError
        def v(version)
          (version || '???').to_s.sub(/^(?=\d)/, 'v')
        end
      end

      class MultipleInstalledError < UpgradeError
        def initialize(options)
          @module_name = options[:module_name]
          @modules     = options[:installed_modules]
          super "Could not upgrade '#{@module_name}'; module appears in multiple places in the module path"
        end
        
        def multiline
          message = []
          message << "Could not upgrade module '#{@module_name}'"
          message << "  Module '#{@module_name}' appears multiple places in the module path"
          message += @modules.map do |mod|
            "    '#{@module_name}' (#{v(mod.version)}) was found in #{mod.path.sub(/#{File::Separator}(#{mod.name})$/, '')}"
          end
          message << "    Use the `--modulepath` option to limit the search to specific directories"
          message.join("\n")
        end
      end

      class NotInstalledError < UpgradeError
        def initialize(options)
          @module_name = options[:module_name]
          super "Could not upgrade '#{@module_name}'; module is not installed"
        end

        def multiline
          message = []
          message << "Could not upgrade module '#{@module_name}'"
          message << "  Module '#{@module_name}' is not installed"
          message << "    Use `puppet module install` to install this module"
          message.join("\n")
        end
      end

      class UnknownModuleError < UpgradeError
        def initialize(options)
          @module_name       = options[:module_name]
          @installed_version = options[:installed_version]
          @requested_version = options[:requested_version]
          @repository        = options[:repository]
          super "Could not upgrade '#{@module_name}'; module is unknown to #{@repository}"
        end

        def multiline
          message = []
          message << "Could not upgrade module '#{@module_name}' (#{v(@installed_version)} -> #{v(@requested_version)})"
          message << "  Module '#{@module_name}' does not exist on #{@repository}"
          message.join("\n")
        end
      end

      class UnknownVersionError < UpgradeError
        def initialize(options)
          @module_name       = options[:module_name]
          @installed_version = options[:installed_version]
          @requested_version = options[:requested_version]
          @repository        = options[:repository]
          super "Could not upgrade '#{@module_name}' (#{v(@installed_version)} -> #{v(@requested_version)}); module has no versions #{ @requested_version && "matching #{v(@requested_version)} "}published on #{@repository}"
        end

        def multiline
          message = []
          message << "Could not upgrade module '#{@module_name}' (#{v(@installed_version)} -> #{v(@requested_version)})"
          message << "  No version matching '#{@requested_version || ">= 0.0.0"}' exists on #{@repository}"
          message.join("\n")
        end
      end

      class NoVersionsSatisfyError < UpgradeError
        attr_accessor :requested_module, :requested_version

        def initialize(options)
          @module_name       = options[:module_name]
          @requested_version = v(options[:requested_version])
          @installed_version = v(options[:installed_version])
          @dependency_name   = options[:dependency_name]
          @conditions        = options[:conditions]
          @source            = options[:source]
          super "Could not upgrade '#{@module_name}' (#{v(@installed_version)} -> #{v(@requested_version)}); module '#{@dependency_name}' cannot satisfy dependencies"
        end

        def multiline
          message = []
          message << "Could not upgrade module '#{@module_name}' (#{v(@installed_version)} -> #{v(@requested_version)})"
          message << "  No version of '#{@dependency_name}' will satisfy dependencies"
          message += @conditions.select { |c| c[:module] == :you }.map do |c|
            "    You specified '#{@dependency_name}' (#{v(c[:version])})"
          end
          message += @conditions.select { |c| c[:module] != :you }.map do |c|
             "    '#{c[:module]}' (#{v(c[:version])}) requires '#{@dependency_name}' (#{v(c[:dependency])})"
          end
          message << "    Use `puppet module upgrade --force` to install this module anyway"
          message.join("\n")
        end
      end

      def initialize(name, options)
        @environment = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @module_name = name
        @options = options
        @version = options[:version]
      end

      def run
        results = { }

        begin
          @local = get_local_constraints

          if @installed[@module_name].length > 1
            raise MultipleInstalledError,
              :module_name       => @module_name,
              :installed_modules => @installed[@module_name].sort_by { |mod| @environment.modulepath.index(mod.path.sub(/#{File::Separator}#{mod.name}$/, '')) }
          elsif @installed[@module_name].empty?
            raise NotInstalledError, :module_name => @module_name
          end

          @module = @installed[@module_name].last
          results[:module_name] = @module_name
          results[:installed_version] = @module.version ? @module.version.sub(/^(?=\d)/, 'v') : nil
          results[:requested_version] = @options[:version] || (@conditions[@module_name].empty? ? :latest : :best)
          dir = @module.path.sub(/\/#{@module.name}/, '')
          Puppet.notice "Found '#{@module_name}' (#{results[:installed_version] || '???'}) in #{dir} ..."

          begin
            Puppet.notice "Downloading from #{Puppet::Forge.repository.uri} ..."
            @author, @modname = Puppet::Module::Tool.username_and_modname_from(@module_name)
            @remote = get_remote_constraints
          rescue => e
            raise UnknownModuleError, results.merge(:repository => Puppet::Forge.repository.uri)
          else
            raise UnknownVersionError, results.merge(:repository => Puppet::Forge.repository.uri) if @remote.empty?
          end

          raise "Already there!" if @versions["#{@module_name}"].sort_by { |h| h[:semver] }.last[:vstring].sub(/^(?=\d)/, 'v') == (@module.version || '0.0.0').sub(/^(?=\d)/, 'v')

          @graph = resolve_constraints({ @module_name => @version })

          tarballs = download_tarballs(@graph)

          unless @graph.empty?
            Puppet.notice 'Upgrading -- do not interrupt ...'
            tarballs.each do |hash|
              hash.each do |dir, path|
                Unpacker.new(path, @options.merge(:dir => dir)).run
              end
            end
          end

          results[:result] = :success
          results[:base_dir] = @graph.first[:path]
          results[:affected_modules] = @graph
        rescue => e
          results[:error] = {
            :oneline => e.message,
            :multiline => e.respond_to?(:multiline) ? e.multiline : [e.to_s, e.backtrace].join("\n")
          }
        ensure
          results[:result] ||= :failure
        end

        return results
      end

      private
      def get_local_constraints
        @conditions = Hash.new { |h,k| h[k] = [] }
        @installed = Hash.new { |h,k| h[k] = [] }
        @environment.modules_by_path.values.flatten.inject(Hash.new { |h,k| h[k] = { } }) do |deps, mod|
          deps.tap do
            mod_name = (mod.forge_name || mod.name).gsub('/', '-')
            @installed[mod_name] << mod
            d = deps["#{mod_name}@#{mod.version}"]
            (mod.dependencies || []).each do |hash|
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
        @urls = {}
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

      def resolve_constraints(dependencies, source = [{:name => :you}], seen = {})
        dependencies = dependencies.map do |mod, range|
          action = :upgrade

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

          # if seen.include? mod
          #   next if range === seen[mod][:semver]
          #   raise InvalidDependencyCycleError,
          #     :requested_module  => @module_name,
          #     :requested_version => @version || (best_requested_versions.empty? ? 'latest' : "latest: #{best_requested_versions.last[:semver]}"),
          #     :dependency_name   => mod,
          #     :source            => source,
          #     :conditions        => @conditions[mod]
          # end

          if !(@force || @installed[mod].empty?) && source.last[:name] != :you
            next if range === SemVer.new(@installed[mod].last.version)
            action = :upgrade
          elsif action == :upgrade && @installed[mod].empty?
            action = :install
          end

          action == :upgrade && @conditions.each do |_, conditions|
            conditions.delete_if { |c| c[:module] == mod }
          end

          valid_versions = @versions["#{mod}"].select { |h| @force || range === h[:semver] } \
                                              .sort_by { |h| h[:semver] }

          unless version = valid_versions.last
            raise NoVersionsSatisfyError,
              :module_name       => @module_name,
              :requested_version => @version || ((@conditions[@module_name].length == 1 ? 'latest' : 'best') + (seen[@module_name] ? ": #{seen[@module_name][:vstring].sub(/^(?=\d)/, 'v')}" : '')),
              :installed_version => @installed[@module_name].last.version,
              :dependency_name   => mod,
              :conditions        => @conditions[mod]
              # :source            => source.last,
              # :version           => valid_versions.empty? ? 'best' : "best: #{valid_versions.last}",
          end

          seen[mod] = version

          {
            :module => mod,
            :version => version,
            :action => action,
            :previous_version => @installed[mod].last.version,
            :file => @urls["#{mod}@#{version[:vstring]}"],
            :path => @installed[mod].empty? ? nil : @installed[mod].last.path.sub(/\/#{@installed[mod].last.name}/, ''),
            :dependencies => []
          }
        end.compact
        dependencies.each do |mod|
          deps = @remote["#{mod[:module]}@#{mod[:version][:vstring]}"].sort_by(&:first)
          mod[:dependencies] = resolve_constraints(deps, source + [{ :name => mod[:module], :version => mod[:version][:vstring] }], seen)
        end unless @options[:ignore_dependencies] || @force
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
          [ {release[:path] => cache_path}, *download_tarballs(release[:dependencies]) ]
        end.flatten
      end
    end
  end
end