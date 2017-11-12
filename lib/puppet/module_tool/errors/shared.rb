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
      #TRANSLATORS `puppet module %{action} --ignore-dependencies` is a command line and should not be translated
      _(<<-EOM).chomp % { action: @action, module_name: @requested_name, version: vstring }
Could not %{action} module '%{module_name}' (%{version})
  No version of '%{module_name}' can satisfy all dependencies
    Use `puppet module %{action} --ignore-dependencies` to %{action} only this module
      EOM
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
      if @requested_version == :latest
        _(<<-EOM).chomp % { action: @action, module_name: @module_name, version: vstring, source: @source }
Could not %{action} '%{module_name}' (%{version})
  No releases are available from %{source}
    Does '%{module_name}' have at least one published release?
        EOM
      else
        _(<<-EOM).chomp % { action: @action, module_name: @module_name, version: vstring, requested_version: @requested_version, source: @source }
Could not %{action} '%{module_name}' (%{version})
  No releases matching '%{requested_version}' are available from %{source}
        EOM
      end
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
      if @dependency
        if @metadata
          msg_variables = { module_name: @requested_module, requested_version: @requested_version,
                       name: @dependency[:name], version: v(@dependency[:version]),
                       directory: @directory, current_name: @metadata["name"], current_version: v(@metadata["version"]) }
          #TRANSLATORS `puppet module install --ignore-dependencies` is a command line and should not be translated
          _(<<-EOM).chomp % msg_variables
Could not install module '%{module_name}' (%{requested_version})                  
  Dependency '%{name}' (%{version}) would overwrite %{directory}
    Currently, '%{current_name}' (%{current_version}) is installed to that directory
    Use `puppet module install --ignore-dependencies` to install only this module
          EOM
        else
          msg_variables = { module_name: @requested_module, requested_version: @requested_version,
                            name: @dependency[:name], version: v(@dependency[:version]), directory: @directory }
          #TRANSLATORS `puppet module install --ignore-dependencies` is a command line and should not be translated
          _(<<-EOM).chomp % msg_variables
Could not install module '%{module_name}' (%{requested_version})                  
  Dependency '%{name}' (%{version}) would overwrite %{directory}
    Use `puppet module install --ignore-dependencies` to install only this module
          EOM
        end

      else
        if @metadata
          msg_variables = { module_name: @requested_module, requested_version: @requested_version,
                            directory: @directory, current_name: @metadata["name"], current_version: v(@metadata["version"]) }
          #TRANSLATORS `puppet module install --force` is a command line and should not be translated
          _(<<-EOM).chomp % msg_variables
Could not install module '%{module_name}' (%{requested_version})
  Installation would overwrite %{directory}
    Currently, '%{current_name}' (%{current_version}) is installed to that directory
    Use `puppet module install --force` to install this module anyway
          EOM
        else
          #TRANSLATORS `puppet module install --force` is a command line and should not be translated
          _(<<-EOM).chomp % { module_name: @requested_module, requested_version: @requested_version, directory: @directory }
Could not install module '%{module_name}' (%{requested_version})
  Installation would overwrite %{directory}
    Use `puppet module install --force` to install this module anyway
          EOM
        end
      end
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
      dependency_list = @source[1..-1].map do |m|
        #TRANSLATORS This message repeats as separate lines as a list under the heading "You specified '%{name}' (%{version})\n"
        _("    which depends on '%{name}' (%{version})") % { name: m[:name], version: v(m[:version]) }
      end.join(",\n")

      msg_variables = { requested_module_name: @requested_module, version: v(@requested_version), module_name: @module_name,
                        name: @source.first[:name], dependency_list: dependency_list }
      #TRANSLATORS `puppet module install --force` is a command line and should not be translated
      _(<<-EOM).chomp % msg_variables
Could not install module '%{requested_module_name}' (%{version})
  No version of '%{module_name}' will satisfy dependencies
    You specified '%{name}' (%{version})
%{dependency_list}
    Use `puppet module install --force` to install this module anyway
      EOM
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
      suggestion_list = @suggestions.map do |suggestion|
        _("    You may have meant `puppet module %{action} %{suggestion}`") % { action: @action, suggestion: suggestion }
      end.join("\n")

      if @action == :upgrade
        # TRANSLATORS `puppet module install` is a command line and should not be translated
        _(<<-EOM).chomp % { action: @action, module_name: @module_name, suggestion_list: suggestion_list }
Could not %{action} module '%{module_name}'
  Module '%{module_name}' is not installed
%{suggestion_list}
    Use `puppet module install` to install this module
        EOM
      else
        _(<<-EOM).chomp % { action: @action, module_name: @module_name, suggestion_list: suggestion_list }
Could not %{action} module '%{module_name}'
  Module '%{module_name}' is not installed
%{suggestion_list}
        EOM
      end
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
      module_path_list = @modules.map do |mod|
        #TRANSLATORS This is repeats as separate lines as a list under "Module '%{module_name}' appears multiple places in the module path"
        _("    '%{module_name}' (%{version}) was found in %{path}") % { module_name: @module_name, version: v(mod.version), path: mod.modulepath }
      end.join("\n")

      # TRANSLATORS `--modulepath` is command line option and should not be translated
      _(<<-EOM).chomp % { action: @action, module_name: @module_name, module_path_list: module_path_list }
Could not %{action} module '%{module_name}'
  Module '%{module_name}' appears multiple places in the module path
%{module_path_list}
    Use the `--modulepath` option to limit the search to specific directories
      EOM
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
      #TRANSLATORS `puppet module %{action} --ignore-changes` is a command line and should not be translated
      _(<<-EOM).chomp % { action: @action, module_name: @module_name, version: vstring }
Could not %{action} module '%{module_name}' (%{version})
  Installed module has had changes made locally
    Use `puppet module %{action} --ignore-changes` to %{action} this module anyway
      EOM
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
      _(<<-EOM).chomp % { action: @action, module_name: @name, message: @error.message }
Could not %{action} module '%{module_name}'
  Failure trying to parse metadata
    Original message was: %{message}
      EOM
    end
  end
end
