module Puppet::ModuleTool
  module Applications
    class Upgrader < Application

      include Puppet::ModuleTool::Errors

      def initialize(name, forge, options)
        @action              = :upgrade
        @environment         = Puppet::Node::Environment.new(Puppet.settings[:environment])
        @module_name         = name
        @options             = options
        @force               = options[:force]
        @ignore_dependencies = options[:force] || options[:ignore_dependencies]
        @version             = options[:version]
        @forge               = forge
      end

      def run
        begin
          results = { :module_name => @module_name }

          get_local_constraints

          if @installed[@module_name].length > 1
            raise MultipleInstalledError,
              :action            => :upgrade,
              :module_name       => @module_name,
              :installed_modules => @installed[@module_name].sort_by { |mod| @environment.modulepath.index(mod.modulepath) }
          elsif @installed[@module_name].empty?
            raise NotInstalledError,
              :action      => :upgrade,
              :module_name => @module_name
          end

          @module = @installed[@module_name].last
          results[:installed_version] = @module.version ? @module.version.sub(/^(?=\d)/, 'v') : nil
          results[:requested_version] = @version || (@conditions[@module_name].empty? ? :latest : :best)
          dir = @module.modulepath

          Puppet.notice "Found '#{@module_name}' (#{colorize(:cyan, results[:installed_version] || '???')}) in #{dir} ..."
          if !@options[:force] && @module.has_metadata? && @module.has_local_changes?
            raise LocalChangesError,
              :action            => :upgrade,
              :module_name       => @module_name,
              :requested_version => @version || (@conditions[@module_name].empty? ? :latest : :best),
              :installed_version => @module.version
          end

          begin
            get_remote_constraints(@forge)
          rescue => e
            raise UnknownModuleError, results.merge(:repository => @forge.uri)
          else
            raise UnknownVersionError, results.merge(:repository => @forge.uri) if @remote.empty?
          end

          if !@options[:force] && @versions["#{@module_name}"].last[:vstring].sub(/^(?=\d)/, 'v') == (@module.version || '0.0.0').sub(/^(?=\d)/, 'v')
            raise VersionAlreadyInstalledError,
              :module_name       => @module_name,
              :requested_version => @version || ((@conditions[@module_name].empty? ? 'latest' : 'best') + ": #{@versions["#{@module_name}"].last[:vstring].sub(/^(?=\d)/, 'v')}"),
              :installed_version => @installed[@module_name].last.version,
              :conditions        => @conditions[@module_name] + [{ :module => :you, :version => @version }]
          end

          @graph = resolve_constraints({ @module_name => @version })

          # This clean call means we never "cache" the module we're installing, but this
          # is desired since module authors can easily rerelease modules different content but the same
          # version number, meaning someone with the old content cached will be very confused as to why
          # they can't get new content.
          # Long term we should just get rid of this caching behavior and cleanup downloaded modules after they install
          # but for now this is a quick fix to disable caching
          Puppet::Forge::Cache.clean
          tarballs = download_tarballs(@graph, @graph.last[:path], @forge)

          unless @graph.empty?
            Puppet.notice 'Upgrading -- do not interrupt ...'
            tarballs.each do |hash|
              hash.each do |dir, path|
                Unpacker.new(path, @options.merge(:target_dir => dir)).run
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
      include Puppet::ModuleTool::Shared
    end
  end
end
