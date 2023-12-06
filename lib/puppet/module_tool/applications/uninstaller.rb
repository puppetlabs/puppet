# frozen_string_literal: true
module Puppet::ModuleTool
  module Applications
    class Uninstaller < Application
      include Puppet::ModuleTool::Errors

      def initialize(name, options)
        super(options)
        @name        = name
        @errors      = Hash.new {|h, k| h[k] = {}}
        @unfiltered  = []
        @installed   = []
        @suggestions = []
        @environment = options[:environment_instance]
        @ignore_changes = options[:force] || options[:ignore_changes]
      end

      def run
        results = {
          :module_name       => @name,
          :requested_version => @version,
        }

        begin
          find_installed_module
          validate_module

          FileUtils.rm_rf(@installed.first.path, :secure => true)

          results[:affected_modules] = @installed
          results[:result] = :success
        rescue ModuleToolError => err
          results[:error] = {
            :oneline   => err.message,
            :multiline => err.multiline,
          }
        rescue => e
          results[:error] = {
            :oneline => e.message,
            :multiline => e.respond_to?(:multiline) ? e.multiline : [e.to_s, e.backtrace].join("\n")
          }
        ensure
          results[:result] ||= :failure
        end

        results
      end

      private

      def find_installed_module
        @environment.modules_by_path.values.flatten.each do |mod|
          mod_name = (mod.forge_name || mod.name).tr('/', '-')
          if mod_name == @name
            @unfiltered << {
              :name    => mod_name,
              :version => mod.version,
              :path    => mod.modulepath,
            }
            if @options[:version] && mod.version
              next unless Puppet::Module.parse_range(@options[:version]).include?(SemanticPuppet::Version.parse(mod.version))
            end
            @installed << mod
          elsif mod_name =~ /#{@name}/
            @suggestions << mod_name
          end
        end

        if @installed.length > 1
          raise MultipleInstalledError,
            :action            => :uninstall,
            :module_name       => @name,
            :installed_modules => @installed.sort_by { |mod| @environment.modulepath.index(mod.modulepath) }
        elsif @installed.empty?
          if @unfiltered.empty?
            raise NotInstalledError,
              :action      => :uninstall,
              :suggestions => @suggestions,
              :module_name => @name
          else
            raise NoVersionMatchesError,
              :installed_modules => @unfiltered.sort_by { |mod| @environment.modulepath.index(mod[:path]) },
              :version_range     => @options[:version],
              :module_name       => @name
          end
        end
      end

      def validate_module
        mod = @installed.first

        unless @ignore_changes
          raise _("Either the `--ignore_changes` or `--force` argument must be specified to uninstall modules when running in FIPS mode.") if Puppet.runtime[:facter].value(:fips_enabled)

          changes = begin
            Puppet::ModuleTool::Applications::Checksummer.run(mod.path)
          rescue ArgumentError
            []
          end

          if mod.has_metadata? && !changes.empty?
            raise LocalChangesError,
              :action            => :uninstall,
              :module_name       => (mod.forge_name || mod.name).tr('/', '-'),
              :requested_version => @options[:version],
              :installed_version => mod.version
          end
        end

        if !@options[:force] && !mod.required_by.empty?
          raise ModuleIsRequiredError,
            :module_name       => (mod.forge_name || mod.name).tr('/', '-'),
            :required_by       => mod.required_by,
            :requested_version => @options[:version],
            :installed_version => mod.version
        end
      end
    end
  end
end
