module Puppet::ModuleTool::Errors

  class InstallError < ModuleToolError; end

  class AlreadyInstalledError < InstallError
    def initialize(options)
      @module_name       = options[:module_name]
      @installed_version = v(options[:installed_version])
      @requested_version = v(options[:requested_version])
      @local_changes     = options[:local_changes]
      super _("'%{module_name}' (%{version}) requested; '%{module_name}' (%{installed_version}) already installed") % { module_name: @module_name, version: @requested_version, installed_version: @installed_version }
    end

    def multiline
      message = []
      message << _("Could not install module '%{module_name}' (%{version})") % { module_name: @module_name, version: @requested_version }
      message << _("  Module '%{module_name}' (%{installed_version}) is already installed") % { module_name: @module_name, installed_version: @installed_version }
      message << _("    Installed module has had changes made locally") unless @local_changes.empty?
      #TRANSLATORS `puppet module upgrade` is a command line and should not be translated
      message << _("    Use `puppet module upgrade` to install a different version")
      #TRANSLATORS `puppet module install --force` is a command line and should not be translated
      message << _("    Use `puppet module install --force` to re-install only this module")
      message.join("\n")
    end
  end

  class MissingPackageError < InstallError
    def initialize(options)
      @requested_package = options[:requested_package]
      @source = options[:source]

      super _("Could not install '%{requested_package}'; no releases are available from %{source}") % { requested_package: @requested_package, source: @source }
    end

    def multiline
      message = []
      message << _("Could not install '%{requested_package}'") % { requested_package: @requested_package }
      message << _("  No releases are available from %{source}") % { source: @source }
      message << _("    Does '%{requested_package}' have at least one published release?") % { requested_package: @requested_package }
      message.join("\n")
    end
  end

  class InstallPathExistsNotDirectoryError < InstallError
    def initialize(original, options)
      @requested_module  = options[:requested_module]
      @requested_version = options[:requested_version]
      @directory         = options[:directory]
      super(_("'%{module_name}' (%{version}) requested; Path %{dir} is not a directory.") % { module_name: @requested_module, version: @requested_version, dir: @directory }, original)
    end

    def multiline
      message = []
      message << _("Could not install module '%{module_name}' (%{version})") % { module_name: @requested_module, version: @requested_version }
      message << _("  Path '%{directory}' exists but is not a directory.") % { directory: @directory }
      #TRANSLATORS "mkdir -p '%{directory}'" is a command line example and should not be translated
      message << _("  A potential solution is to rename the path and then \"mkdir -p '%{directory}'\"") % { directory: @directory }
      message.join("\n")
    end
  end

  class PermissionDeniedCreateInstallDirectoryError < InstallError
    def initialize(original, options)
      @requested_module  = options[:requested_module]
      @requested_version = options[:requested_version]
      @directory         = options[:directory]
      super(_("'%{module_name}' (%{version}) requested; Permission is denied to create %{dir}.") % { module_name: @requested_module, version: @requested_version, dir: @directory }, original)
    end

    def multiline
      message = []
      message << _("Could not install module '%{module_name}' (%{version})") % { module_name: @requested_module, version: @requested_version }
      message << _("  Permission is denied when trying to create directory '%{directory}'.")  % { directory: @directory }
      message << _('  A potential solution is to check the ownership and permissions of parent directories.')
      message.join("\n")
    end
  end

  class InvalidPathInPackageError < InstallError
    def initialize(options)
      @entry_path = options[:entry_path]
      @directory  = options[:directory]
      super _("Attempt to install file with an invalid path into %{path} under %{dir}") % { path: @entry_path.inspect, dir: @directory.inspect }
    end

    def multiline
      message = []
      message << _('Could not install package with an invalid path.')
      message << _('  Package attempted to install file into %{path} under %{directory}.') % { path: @entry_path.inspect, directory: @directory.inspect }
      message.join("\n")
    end
  end
end
