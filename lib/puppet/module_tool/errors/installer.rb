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

      message << "    Use `puppet module install --dir <DIR>` to install modules elsewhere"

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

  class MissingInstallDirectoryError < InstallError
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
