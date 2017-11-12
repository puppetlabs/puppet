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
      if @local_changes.empty?
        #TRANSLATORS `puppet module upgrade` and `puppet module upgrade` are a command line and should not be translated
        _(<<-MSG).chomp % { module_name: @module_name, requested_version: @requested_version, installed_version: @installed_version }
Could not install module '%{module_name}' (%{requested_version})
  Module '%{module_name}' (%{installed_version}) is already installed
    Use `puppet module upgrade` to install a different version
    Use `puppet module install --force` to re-install only this module
        MSG
      else
        #TRANSLATORS `puppet module upgrade` and `puppet module upgrade` are a command line and should not be translated
        _(<<-MSG).chomp % { module_name: @module_name, requested_version: @requested_version, installed_version: @installed_version }
Could not install module '%{module_name}' (%{requested_version})
  Module '%{module_name}' (%{installed_version}) is already installed
    Installed module has had changes made locally
    Use `puppet module upgrade` to install a different version
    Use `puppet module install --force` to re-install only this module
        MSG
      end
    end
  end

  class MissingPackageError < InstallError
    def initialize(options)
      @requested_package = options[:requested_package]
      @source = options[:source]

      super _("Could not install '%{requested_package}'; no releases are available from %{source}") % { requested_package: @requested_package, source: @source }
    end

    def multiline
      _(<<-MSG).chomp % { requested_package: @requested_package, source: @source }
Could not install '%{requested_package}'
  No releases are available from %{source}
    Does '%{requested_package}' have at least one published release?
MSG
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
      # TRANSLATORS "mkdir -p'%{dir}'" is a command line example and should not be translated
      _(<<-MSG).chomp % { module_name: @requested_module, version: @requested_version, dir: @directory }
Could not install module '%{module_name}' (%{version})
  Path '%{dir}' exists but is not a directory.
  A potential solution is to rename the path and then
  mkdir -p '%{dir}'
      MSG
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
      _(<<-MSG).chomp % { module_name: @requested_module, version: @requested_version, dir: @directory }
Could not install module '%{module_name}' (%{version})
  Permission is denied when trying to create directory '%{dir}'.
  A potential solution is to check the ownership and permissions of
  parent directories.
      MSG
    end
  end

  class InvalidPathInPackageError < InstallError
    def initialize(options)
      @entry_path = options[:entry_path]
      @directory  = options[:directory]
      super _("Attempt to install file with an invalid path into %{path} under %{dir}") % { path: @entry_path.inspect, dir: @directory.inspect }
    end

    def multiline
      _(<<-MSG).chomp % { path: @entry_path.inspect, dir: @directory.inspect }
Could not install package with an invalid path.
  Package attempted to install file into
  %{path} under %{dir}.
      MSG
    end
  end
end
