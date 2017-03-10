module Puppet::ModuleTool::Errors

  class NoVersionsSatisfyError < ModuleToolError
    def initialize(options)
      @requested_name    = options[:requested_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @conditions        = options[:conditions]
      @action            = options[:action]

      super _("Could not %{action} '%{module_name}' (%{version}); no version satisfies all dependencies") % { action: @action, module_name: @requested_name, version: vstring }
    end

    def multiline
      message = []
      message << _("Could not %{action} module '%{module_name}' (%{version})") % { action: @action, module_name: @requested_name, version: vstring }
      message << _("  No version of '%{module_name}' can satisfy all dependencies") % { module_name: @requested_name }
      message << _("    Use `puppet module %{action} --ignore-dependencies` to %{action} only this module") % { action: @action }

      message.join("\n")
    end
  end

  class NoCandidateReleasesError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @source            = options[:source]
      @action            = options[:action]

      if @requested_version == :latest
        super _("Could not %{action} '%{module_name}'; no releases are available from %{source}") % { action: @action, module_name: @module_name, source: @source }
      else
        super _("Could not %{action} '%{module_name}'; no releases matching '%{version}' are available from %{source}") % { action: @action, module_name: @module_name, version: @requested_version, source: @source }
      end
    end

    def multiline
      message = []
      message << _("Could not %{action} '%{module_name}' (%{version})") % { action: @action, module_name: @module_name, version: vstring }

      if @requested_version == :latest
        message << _("  No releases are available from %{source}") % { source: @source }
        message << _("    Does '%{module_name}' have at least one published release?") % { module_name: @module_name }
      else
        message << _("  No releases matching '%{version}' are available from %{source}") % { version: @requested_version, source: @source }
      end

      message.join("\n")
    end
  end

  class InstallConflictError < ModuleToolError
    def initialize(options)
      @requested_module  = options[:requested_module]
      @requested_version = v(options[:requested_version])
      @dependency        = options[:dependency]
      @directory         = options[:directory]
      @metadata          = options[:metadata]
      super _("'%{module_name}' (%{version}) requested; installation conflict") % { module_name: @requested_module, version: @requested_version }
    end

    def multiline
      message = []
      message << _("Could not install module '%{module_name}' (%{version})") % { module_name: @requested_module, version: @requested_version }

      if @dependency
        message << _("  Dependency '%{name}' (%{version}) would overwrite %{dir}") % { name: @dependency[:name], version: v(@dependency[:version]), dir: @directory }
      else
        message << _("  Installation would overwrite %{dir}") % { dir: @directory }
      end

      if @metadata
        message << _("    Currently, '%{name}' (%{version}) is installed to that directory") % { name: @metadata["name"], version: v(@metadata["version"]) }
      end

      if @dependency
        message << _("    Use `puppet module install --ignore-dependencies` to install only this module")
      else
        message << _("    Use `puppet module install --force` to install this module anyway")
      end

      message.join("\n")
    end
  end

  class InvalidDependencyCycleError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_module  = options[:requested_module]
      @requested_version = options[:requested_version]
      @conditions        = options[:conditions]
      @source            = options[:source][1..-1]

      super _("'%{module_name}' (%{version}) requested; Invalid dependency cycle") % { module_name: @requested_module, version: v(@requested_version) }
    end

    def multiline
      trace = []
      trace << _("You specified '%{name}' (%{version})") % { name: @source.first[:name], version: v(@requested_version) }
      #TRANSLATORS Second half of "You specified a module..."
      trace += @source[1..-1].map { |m| _("which depends on '%{name}' (%{version})") % { name: m[:name], version: v(m[:version]) } }

      message = []
      message << _("Could not install module '%{module_name}' (%{version})") % { module_name: @requested_module, version: v(@requested_version) }
      message << _("  No version of '%{module_name}' will satisfy dependencies") % { module_name: @module_name }
      message << trace.map { |s| "    #{s}".join(",\n") }
      message << _("    Use `puppet module install --force` to install this module anyway")

      message.join("\n")
    end
  end

  class NotInstalledError < ModuleToolError
    def initialize(options)
      @module_name = options[:module_name]
      @suggestions = options[:suggestions] || []
      @action      = options[:action]
      super _("Could not %{action} '%{module_name}'; module is not installed") % { action: @action, module_name: @module_name }
    end

    def multiline
      message = []
      message << _("Could not %{action} module '%{module_name}'") % { action: @action, module_name: @module_name }
      message << _("  Module '%{module_name}' is not installed") % { module_name: @module_name }
      message += @suggestions.map do |suggestion|
        _("    You may have meant `puppet module %{action} %{suggestion}`") % { action: @action, suggestion: suggestion }
      end
      message << _("    Use `puppet module install` to install this module") if @action == :upgrade
      message.join("\n")
    end
  end

  class MultipleInstalledError < ModuleToolError
    def initialize(options)
      @module_name = options[:module_name]
      @modules     = options[:installed_modules]
      @action      = options[:action]
      #TRANSLATORS "module path" refers to a set of directories where modules may be installed
      super _("Could not %{action} '%{module_name}'; module appears in multiple places in the module path") % { action: @action, module_name: @module_name }
    end

    def multiline
      message = []
      message << _("Could not %{action} module '%{module_name}'") % { action: @action, module_name: @module_name }
      message << _("  Module '%{module_name}' appears multiple places in the module path") % { module_name: @module_name }
      message += @modules.map do |mod|
        _("    '%{module_name}' (%{version}) was found in %{path}") % { module_name: @module_name, version: v(mod.version), path: mod.modulepath }
      end
      message << _("    Use the `--modulepath` option to limit the search to specific directories")
      message.join("\n")
    end
  end

  class LocalChangesError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @action            = options[:action]
      super _("Could not %{action} '%{module_name}'; module has had changes made locally") % { action: @action, module_name: @module_name }
    end

    def multiline
      message = []
      message << _("Could not %{action} module '%{module_name}' (%{version})") % { action: @action, module_name: @module_name, version: vstring }
      message << _("  Installed module has had changes made locally")
      message << _("    Use `puppet module %{action} --ignore-changes` to %{action} this module anyway") % { action: @action }
      message.join("\n")
    end
  end

  class InvalidModuleError < ModuleToolError
    def initialize(name, options)
      @name   = name
      @action = options[:action]
      @error  = options[:error]
      super _("Could not %{action} '%{module_name}'; %{error}") % { action: @action, module_name: @name, error: @error.message }
    end

    def multiline
      message = []
      message << _("Could not %{action} module '%{module_name}'") % { action: @action, module_name: @name }
      message << _("  Failure trying to parse metadata")
      message << _("    Original message was: %{message}") % { message: @error.message }
      message.join("\n")
    end
  end
end
