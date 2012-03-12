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
            "    '#{@module_name}' (#{v(mod.version)}) was found in #{mod.modulepath}"
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

      class LocalChangesError < UpgradeError
        def initialize(options)
          @module_name = options[:module_name]
          @requested_version = v(options[:requested_version])
          @installed_version = v(options[:installed_version])
          super "Could not upgrade '#{@module_name}'; module is not installed"
        end

        def multiline
          message = []
          message << "Could not upgrade module '#{@module_name}' (#{v(@installed_version)} -> #{v(@requested_version)})"
          message << "  Installed module has had changes made locally"
          message << "    Use `puppet module upgrade --force` to upgrade this module anyway"
          message.join("\n")
        end
      end

      class VersionAlreadyInstalledError < UpgradeError
        def initialize(options)
          @module_name       = options[:module_name]
          @requested_version = v(options[:requested_version])
          @installed_version = v(options[:installed_version])
          @dependency_name   = options[:dependency_name]
          @conditions        = options[:conditions]
          super "Could not upgrade '#{@module_name}'; module is not installed"
        end

        def multiline
          message = []
          message << "Could not upgrade module '#{@module_name}' (#{v(@installed_version)} -> #{v(@requested_version)})"
          if @conditions.length == 1 && @conditions.last[:version].nil?
            message << "  The installed version is already the latest version"
          else
            message << "  The installed version is already the best fit for the current dependencies"
            message += @conditions.select { |c| c[:module] == :you && c[:version] }.map do |c|
              "    You specified '#{@module_name}' (#{v(c[:version])})"
            end
            message += @conditions.select { |c| c[:module] != :you }.sort_by { |c| c[:module] }.map do |c|
               "    '#{c[:module]}' (#{v(c[:version])}) requires '#{@module_name}' (#{v(c[:dependency])})"
            end
          end
          message << "    Use `puppet module install --force` to re-install this module"
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

      def initialize(name, options)
        @action              = :upgrade
        @environment         = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @module_name         = name
        @options             = options
        @force               = options[:force]
        @ignore_dependencies = options[:force] || options[:ignore_dependencies]
        @version             = options[:version]
      end

      def run
        begin
          results = { :module_name => @module_name }

          get_local_constraints

          if @installed[@module_name].length > 1
            raise MultipleInstalledError,
              :module_name       => @module_name,
              :installed_modules => @installed[@module_name].sort_by { |mod| @environment.modulepath.index(mod.modulepath) }
          elsif @installed[@module_name].empty?
            raise NotInstalledError, :module_name => @module_name
          end

          @module = @installed[@module_name].last
          results[:installed_version] = @module.version ? @module.version.sub(/^(?=\d)/, 'v') : nil
          results[:requested_version] = @version || (@conditions[@module_name].empty? ? :latest : :best)
          dir = @module.modulepath

          Puppet.notice "Found '#{@module_name}' (#{results[:installed_version] || '???'}) in #{dir} ..."
          if !@options[:force] && @module.has_metadata? && @module.has_local_changes?
            raise LocalChangesError,
              :module_name       => @module_name,
              :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
              :installed_version => @module.version
          end

          begin
            get_remote_constraints
          rescue => e
            raise UnknownModuleError, results.merge(:repository => Puppet::Forge.repository.uri)
          else
            raise UnknownVersionError, results.merge(:repository => Puppet::Forge.repository.uri) if @remote.empty?
          end

          if !@options[:force] && @versions["#{@module_name}"].last[:vstring].sub(/^(?=\d)/, 'v') == (@module.version || '0.0.0').sub(/^(?=\d)/, 'v')
            raise VersionAlreadyInstalledError,
              :module_name       => @module_name,
              :requested_version => @version || ((@conditions[@module_name].empty? ? 'latest' : 'best') + ": #{@versions["#{@module_name}"].last[:vstring].sub(/^(?=\d)/, 'v')}"),
              :installed_version => @installed[@module_name].last.version,
              :conditions        => @conditions[@module_name] + [{ :module => :you, :version => @version }]
          end

          @graph = resolve_constraints({ @module_name => @version })

          tarballs = download_tarballs(@graph, @graph.last[:path])

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
        rescue VersionAlreadyInstalledError => e
          results[:result] = :noop
          results[:error] = {
            :oneline   => e.message,
            :multiline => e.multiline
          }
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
      include Puppet::Module::Tool::Shared
    end
  end
end