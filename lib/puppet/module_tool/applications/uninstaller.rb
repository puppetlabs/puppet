require 'set'

module Puppet::Module::Tool
  module Applications
    class Uninstaller < Application

      def initialize(name, options)
        @name = name
        @options = options
        @errors = Hash.new {|h, k| h[k] = {}}
        @removed_mods = []
        @suggestions = []
        @environment = Puppet::Node::Environment.new(options[:environment])
      end

      def run
        if module_installed?
          uninstall
        else
          msg = "Error: Could not uninstall module '#{@name}':\n"
          msg << "  Module '#{@name}' is not installed\n"
          @suggestions.each do |suggestion|
            msg << "    You may have meant `puppet module uninstall #{suggestion}`\n"
          end
          $stderr << msg
          exit(1)
        end

        if (@errors.count > 0) && @removed_mods.empty?
          @errors.map do |mod_name, details|
            unless details[:errors].empty?
              mod_version = options[:version] || details[:version]

              header = "Error: Could not uninstall module '#{mod_name}'"
              header << " (v#{mod_version})"
              $stderr << "#{header}:\n"
              details[:errors].map { |error| $stderr << "  #{error}\n" }
            end
          end
          exit(1)
        end

        { :removed_mods => @removed_mods, :options => @options }
      end

      private

      def version_match?(mod)
        if @options[:version]
          SemVer[@options[:version]].include? SemVer.new(mod.version)
        else
          true
        end
      end

      # Only match installed modules by forge_name, which ensures the module
      # has proper metadata and a good sign it was install by the module
      # tool.
      def module_installed?
        @environment.modules_by_path.each do |path, modules|
          modules.each do |mod|
            if mod.has_metadata?
              full_name = mod.forge_name.sub('/', '-')
              if full_name == @name
                return true
              else
                if full_name =~ /#{@name}/
                  @suggestions << full_name
                end
              end
            elsif mod.name == @name
               return true
            end
          end
        end

        false
      end

      def uninstall
        @environment.modules_by_path.each do |path, modules|
          modules.each do |mod|

            if mod.has_metadata?
              full_name = mod.forge_name.sub('/', '-')

              if full_name == @name
                @errors[full_name][:version] = mod.version
                @errors[full_name][:errors]  = []

                # If required, check for version match
                unless version_match?(mod)
                  @errors[full_name][:errors] << "Installed version of '#{full_name}' (v#{mod.version}) does not match (v#{@options[:version]})"
                  next
                end

                if mod.has_local_changes?
                  unless @options[:force]
                    @errors[full_name][:errors] << "Installed version of #{full_name} (v#{mod.version}) has local changes"
                  end
                end

                requires_me = mod.required_by
                unless requires_me.empty? or @options[:force]
                  requires_me.each do |req|
                    req_name = req['name'].sub('/', '-')
                    req_version = req['version']

                    @errors[full_name][:errors] << "Module '#{full_name}' (v#{mod.version}) is required by '#{req_name}' (v#{req_version})"
                    @errors[full_name][:errors] << "  Supply the `--force` flag to uninstall this module anyway"
                    next
                  end
                end

                if @errors[full_name][:errors].empty? && @errors[full_name][:version] == mod.version
                  FileUtils.rm_rf(mod.path)
                  @removed_mods << mod
                end
              end
            elsif mod.name == @name
              FileUtils.rm_rf(mod.path)
              @removed_mods << mod
            end
          end
        end
      end
    end
  end
end
