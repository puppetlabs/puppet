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
        def initialize(options)
          @module_name       = options[:module_name      ]
          @installed_version = options[:installed_version].sub(/^(?=\d)/, 'v')
          @requested_version = options[:requested_version]
          @local_changes     = options[:local_changes]
          @requested_version.sub!(/^(?=\d)/, 'v') if @requested_version.is_a? String
          super "'#{@module_name}' (#{@requested_version}) requested; '#{@module_name}' (#{@installed_version}) already installed"
        end

        def multiline
          msg = ''
          msg << "Could not install module '#{@module_name}' (#{@requested_version})\n"
          msg << "  Module '#{@module_name}' (#{@installed_version}) is already installed\n"
          msg << "    Installed module has had changes made locally\n" unless @local_changes.empty?
          msg << "    Use `puppet module upgrade` to install a different version\n"
          msg << "    Use `puppet module install --force` to re-install only this module"
          msg
        end
      end

      class InstallConflictError < InstallException
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
          msg = ''
          msg << "Could not install module '#{@requested_module}' (#{@requested_version})\n"

          if @dependency
            msg << "  Dependency '#{@dependency[:name]}' (#{add_v(@dependency[:version])})"
          else
            msg << "  Installation"
          end

          msg << " would overwrite #{@directory}\n"

          if @metadata
            msg << "    Currently, '#{@metadata[:name]}' (#{add_v(@metadata[:version])}) is installed to that directory\n"
          end

          msg << "    Use `puppet module install --dir <DIR>` to install modules elsewhere\n"

          if @dependency
            msg << "    Use `puppet module install --ignore-dependencies` to install only this module"
          else
            msg << "    Use `puppet module install --force` to install this module anyway"
          end

          msg
        end
      end

      class MissingPackageError < InstallException
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

      class MissingInstallDirectoryError < InstallException
        def initialize(options)
          @requested_module  = options[:requested_module]
          @requested_version = options[:requested_version]
          @directory         = options[:directory]
          super "'#{@requested_module}' (#{@requested_version}) requested; Directory #{@directory} does not exist"
        end

        def multiline
          <<-MSG.strip
Could not install module '#{@requested_module}' (#{@requested_version})
  Directory #{@directory} does not exist
          MSG
        end
      end
    end
  end
end

