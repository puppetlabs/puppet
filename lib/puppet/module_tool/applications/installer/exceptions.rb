module Puppet::Module::Tool
  module Applications
    class Installer

      class InstallException < Exception
        def add_v(version)
          if version.is_a? String
            version.sub(/^(?=\d)/, 'v')
          else
            version
          end
        end
      end

      class AlreadyInstalledError < InstallException
        attr_accessor :module_name, :installed_version, :requested_version

        def initialize(options)
          @module_name       = options[:module_name      ]
          @installed_version = options[:installed_version].sub(/^(?=\d)/, 'v')
          @requested_version = options[:requested_version]
          @local_changes     = options[:local_changes]
          @requested_version.sub!(/^(?=\d)/, 'v') if @requested_version.is_a? String
          super "'#{@module_name}' (#{@requested_version}) requested; '#{@module_name}' (#{@installed_version}) already installed"
        end

        def multiline
          message = ''
          message << "Could not install module '#{@module_name}' (#{@requested_version})\n"
          message << "  Module '#{@module_name}' (#{@installed_version}) is already installed\n"
          message << "    Installed module has had changes made locally\n" unless @local_changes.empty?
          message << "    Use `puppet module upgrade` to install a different version\n"
          message << "    Use `puppet module install --force` to re-install only this module"
          message
        end
      end

      class InstallConflictError < InstallException
        attr_accessor :requested_module, :requested_version
        def initialize(options)
          @requested_module  = options[:requested_module]
          @requested_version = options[:requested_version]
          @requested_version = add_v(@requested_version)
          @dependency        = options[:dependency]
          @directory         = options[:directory]
          @metadata          = options[:metadata]
          super "'#{@requested_module}' (#{@requested_version}) requested; Installation conflict"
        end

        def multiline
          message = ''
          message << "Could not install module '#{@requested_module}' (#{@requested_version})\n"
          if @dependency
            message << "  Dependency '#{@dependency[:name]}' (#{add_v(@dependency[:version])})"
          else
            message << "  Installation"
          end
          message << " would overwrite #{@directory}\n"

          if @metadata
            message << "    Currently, '#{@metadata[:name]}' (#{add_v(@metadata[:version])}) is installed to that directory\n"
          end

          message << "    Use `puppet module install --dir <DIR>` to install modules elsewhere\n"
          if @dependency
            message << "    Use `puppet module install --ignore-dependencies` to install only this module"
          else
            message << "    Use `puppet module install --force` to install this module anyway"
          end

          message
        end
      end

      class MissingPackageError < InstallException
        attr_accessor :requested_package
        def initialize(options)
          @requested_package = options[:requested_package]
          super "#{@requested_package} requested; Currently, #{@requested_package} does not exist"
        end

        def multiline
          <<-MSG.strip
Could not install package #{@requested_package}
  Currently, #{@requested_package} does not exist
    Please check the local filesystem and try again
          MSG
        end
      end

    end
  end
end

