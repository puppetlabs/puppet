require 'set'

module Puppet::Module::Tool
  module Applications
    class Uninstaller < Application

      def initialize(name, options)
        @name = name
        @options = options
        @errors = Hash.new {|h, k| h[k] = []}
        @removed_mods = []
        @environment = Puppet::Node::Environment.new(options[:environment])
      end

      def run
        if module_installed?
          uninstall
        else
          @errors[@name] << "Module #{@name} is not installed"
        end

        { :removed_mods => @removed_mods, :errors => @errors, :options => @options }
      end

      private

      def version_match?(mod)
        if @options[:version]
          mod.version == @options[:version]
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
            return false unless mod.has_metadata?

            full_name = mod.forge_name.sub('/', '-')
            if full_name == @name
              return true
            end
          end
        end
        false
      end

      def has_local_changes?(path)
        changes = Puppet::Module::Tool::Applications::Checksummer.run(path)
        changes == [] ? false : true
      end

      def broken_dependencies(mod)

        requires_me = []
        @environment.modules_by_path.each do |path, modules|
          modules.each do |m|
            next unless m.has_metadata?
            m.dependencies.each do |dep|
              requires_me << m if dep["name"] == mod.forge_name
            end
          end
        end

        requires_me
      end

      def uninstall
        # TODO: #11803 Check for broken dependencies before uninstalling modules.
        @environment.modules_by_path.each do |path, modules|
          modules.each do |mod|
            full_name = mod.forge_name.sub('/', '-')
            if full_name == @name

              # If required, check for version match
              unless version_match?(mod)
                @errors[@name] << "Installed version of #{full_name} (v#{mod.version}) does not match version range"
              end

              # Check for local changes
              if has_local_changes?(mod.path)
                if @options[:force]
                  Puppet.warning "Ignoring local changes..."
                else
                  @errors[@name] << "Installed version of #{full_name} (v#{mod.version}) has local changes"
                end
              end

              # Check from broken dependencies
              requires_me = broken_dependencies(mod)
              if requires_me.count > 0
                if @options[:force]
                  Puppet.warning "Ignoring broken dependencies..."
                else
                  msg = []
                  msg << "Cannot uninstall #{full_name} (v#{mod.version}) still required by:\n"
                  requires_me.each { |m| msg << "  #{m.forge_name.sub('/', '-')} (v#{m.version})" }
                  Puppet.err msg
                  next
                end
              end

              if @errors[@name].empty?
                FileUtils.rm_rf(mod.path)
                @removed_mods << mod
              end
            end
          end
        end
      end
    end
  end
end
