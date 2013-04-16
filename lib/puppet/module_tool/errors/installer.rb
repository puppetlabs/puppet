module Puppet::ModuleTool::Errors

  class InstallError < ModuleToolError; end

  class AlreadyInstalledError < InstallError
    def initialize(options)
      @module_name       = options[:module_name]
      @installed_version = v(options[:installed_version])
      @requested_version = v(options[:requested_version])
      @local_changes     = options[:local_changes]
      super "'#{@module_name}' (#{@requested_version}) requested; '#{@module_name}' (#{@installed_version}) already installed"
    end

    def multiline
      message = []
      message << "Could not install module '#{@module_name}' (#{@requested_version})"
      message << "  Module '#{@module_name}' (#{@installed_version}) is already installed"
      message << "    Installed module has had changes made locally" unless @local_changes.empty?
      message << "    Use `puppet module upgrade` to install a different version"
      message << "    Use `puppet module install --force` to re-install only this module"
      message.join("\n")
    end
  end

  class InstallConflictError < InstallError
    def initialize(options)
      @requested_module  = options[:requested_module]
      @requested_version = v(options[:requested_version])
      @dependency        = options[:dependency]
      @directory         = options[:directory]
      @metadata          = options[:metadata]
      super "'#{@requested_module}' (#{@requested_version}) requested; Installation conflict"
    end

    def multiline
      message = []
      message << "Could not install module '#{@requested_module}' (#{@requested_version})"

      if @dependency
        message << "  Dependency '#{@dependency[:name]}' (#{v(@dependency[:version])}) would overwrite #{@directory}"
      else
        message << "  Installation would overwrite #{@directory}"
      end

      if @metadata
        message << "    Currently, '#{@metadata[:name]}' (#{v(@metadata[:version])}) is installed to that directory"
      end

      message << "    Use `puppet module install --target-dir <DIR>` to install modules elsewhere"

      if @dependency
        message << "    Use `puppet module install --ignore-dependencies` to install only this module"
      else
        message << "    Use `puppet module install --force` to install this module anyway"
      end

      message.join("\n")
    end
  end

  class MissingPackageError < InstallError
    def initialize(options)
      @requested_package = options[:requested_package]
      super "#{@requested_package} requested; Package #{@requested_package} does not exist"
    end

    def multiline
      <<-MSG.strip
Could not install package #{@requested_package}
  Package #{@requested_package} does not exist
      MSG
    end
  end

  class InstallPathExistsNotDirectoryError < InstallError
    def initialize(original, options)
      @requested_module  = options[:requested_module]
      @requested_version = options[:requested_version]
      @directory         = options[:directory]
      super("'#{@requested_module}' (#{@requested_version}) requested; Path #{@directory} is not a directory.", original)
    end

    def multiline
      <<-MSG.strip
Could not install module '#{@requested_module}' (#{@requested_version})
  Path '#{@directory}' exists but is not a directory.
  A potential solution is to rename the path and then
  mkdir -p '#{@directory}'
      MSG
    end
  end

  class PermissionDeniedCreateInstallDirectoryError < InstallError
    def initialize(original, options)
      @requested_module  = options[:requested_module]
      @requested_version = options[:requested_version]
      @directory         = options[:directory]
      super("'#{@requested_module}' (#{@requested_version}) requested; Permission is denied to create #{@directory}.", original)
    end

    def multiline
      <<-MSG.strip
Could not install module '#{@requested_module}' (#{@requested_version})
  Permission is denied when trying to create directory '#{@directory}'.
  A potential solution is to check the ownership and permissions of
  parent directories.
      MSG
    end
  end

  class InvalidPathInPackageError < InstallError
    def initialize(options)
      @requested_package = options[:requested_package]
      @entry_path        = options[:entry_path]
      @directory         = options[:directory]
      super "Attempt to install file into #{@entry_path.inspect} under #{@directory.inspect}"
    end

    def multiline
      <<-MSG.strip
Could not install package #{@requested_package}
  Package #{@requested_package} attempted to install file into
  #{@entry_path.inspect} under #{@directory.inspect}.
      MSG
    end
  end
end
