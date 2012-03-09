module Puppet::Module::Tool
  module Applications
    class Upgrader
      class UpgradeException < Exception
        def add_v(version)
          if version.is_a? String
            version.sub(/^(?=\d)/, 'v')
          else
            version
          end
        end
      end

      class NoVersionSatisfyError < UpgradeException
        attr_accessor :requested_module, :requested_version

        def initialize(options)
          @module_name       = options[:module_name]
          @requested_module  = options[:requested_module]
          @requested_version = options[:requested_version]
          @conditions        = options[:conditions]
          @source            = options[:source]
          @requested_version = add_v(@requested_version)
          super "'#{@requested_module}' (#{@requested_version}) requested; No version of '#{@requested_module}' will satisfy dependencies"
        end

        def multiline
          message = ''
          message << "Could not upgrade module '#{@requested_module}' (#{@requested_version})\n"
          message << "  No version of '#{@requested_module}' will satisfy dependencies:\n"
          message << "    You specified '#{@requested_module}' (#{@requested_version})\n" if @source[:name] == :you
          @conditions[@module_name].select  {|cond| cond[:module] != :you} \
                                   .sort_by {|cond| cond[:module]}.each do |cond|
            message << "    '#{cond[:module]}' (#{add_v(cond[:version])}) requires '#{@module_name}' (#{add_v(cond[:dependency])})\n"
          end

          if @source[:name] == :you
            message << "    Use `puppet module install --force` to install this module anyway"
          else
            message << "    Use `puppet module install --ignore-dependencies` to install only this module"
          end

          message
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

          raise "Too few modules named #{@module_name}!" if @installed[@module_name].length < 1
          raise "Too many modules named #{@module_name}!" if @installed[@module_name].length > 1

          @module = @installed[@module_name].last
          results[:module_name] = @module_name
          results[:installed_version] = @module.version.sub(/^(?=\d)/, 'v')
          results[:requested_version] = @options[:version]
          dir = @module.path.sub(/\/#{@module.name}/, '')
          Puppet.notice "Found '#{@module_name}' (#{results[:installed_version]}) in #{dir} ..."

          Puppet.notice "Downloading from #{Puppet::Forge.repository.uri} ..."
          @author, @modname = Puppet::Module::Tool.username_and_modname_from(@module_name)
          @remote = get_remote_constraints

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
            :multiline => [e.to_s, e.backtrace].join("\n")
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
        @environment.modules.inject(Hash.new { |h,k| h[k] = { } }) do |deps, mod|
          deps.tap do
            mod_name = mod.forge_name.gsub('/', '-')
            @installed[mod_name] << mod
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

          if seen.include? mod
            next if range === seen[mod][:semver]
            raise InvalidDependencyCycleError,
              :module_name       => mod,
              :source            => source,
              :version           => 'v1.0.0',
              :requested_module  => @module_name,
              :requested_version => @version || (best_requested_versions.empty? ? 'latest' : "latest: #{best_requested_versions.last[:semver]}"),
              :conditions        => @conditions
          end

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
            raise NoVersionSatisfyError,
              :module_name       => mod,
              :source            => source.last,
              :version           => valid_versions.empty? ? 'best' : "best: #{valid_versions.last}",
              :requested_module  => @module_name,
              :requested_version => @version || (best_requested_versions.empty? ? 'best' : "best: #{best_requested_versions.last[:semver]}"),
              :conditions        => @conditions
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
          deps = @remote["#{mod[:module]}@#{mod[:version][:vstring]}"]
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