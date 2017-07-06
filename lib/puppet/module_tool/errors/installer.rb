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

  class MissingPackageError < InstallError
    def initialize(options)
      @requested_package = options[:requested_package]
      @source = options[:source]

      super "Could not install '#{@requested_package}'; no releases are available from #{@source}"
    end

    def multiline
      message = []
      message << "Could not install '#{@requested_package}'"

      message << "  No releases are available from #{@source}"
      message << "    Does '#{@requested_package}' have at least one published release?"

      message.join("\n")
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
      @entry_path = options[:entry_path]
      @directory  = options[:directory]
      super "Attempt to install file with an invalid path into #{@entry_path.inspect} under #{@directory.inspect}"
    end

    def multiline
      <<-MSG.strip
Could not install package with an invalid path.
  Package attempted to install file into
  #{@entry_path.inspect} under #{@directory.inspect}.
      MSG
    end
  end
end
