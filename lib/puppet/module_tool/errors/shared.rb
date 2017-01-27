module Puppet::ModuleTool::Errors

  class NoVersionsSatisfyError < ModuleToolError
    def initialize(options)
      @requested_name    = options[:requested_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @conditions        = options[:conditions]
      @action            = options[:action]

      super _("Could not #{@action} '#{@requested_name}' (#{vstring}); no version satisfies all dependencies")
    end

    def multiline
      message = []
      message << _("Could not #{@action} module '#{@requested_name}' (#{vstring})")
      message << _("  No version of '#{@requested_name}' can satisfy all dependencies")
      message << _("    Use `puppet module #{@action} --ignore-dependencies` to #{@action} only this module")

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
        super _("Could not #{@action} '#{@module_name}'; no releases are available from #{@source}")
      else
        super _("Could not #{@action} '#{@module_name}'; no releases matching '#{@requested_version}' are available from #{@source}")
      end
    end

    def multiline
      message = []
      message << _("Could not #{@action} '#{@module_name}' (#{vstring})")

      if @requested_version == :latest
        message << _("  No releases are available from #{@source}")
        message << _("    Does '#{@module_name}' have at least one published release?")
      else
        message << _("  No releases matching '#{@requested_version}' are available from #{@source}")
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
      super _("'#{@requested_module}' (#{@requested_version}) requested; installation conflict")
    end

    def multiline
      message = []
      message << _("Could not install module '#{@requested_module}' (#{@requested_version})")

      if @dependency
        message << _("  Dependency '#{@dependency[:name]}' (#{v(@dependency[:version])}) would overwrite #{@directory}")
      else
        message << _("  Installation would overwrite #{@directory}")
      end

      if @metadata
        message << _("    Currently, '#{@metadata["name"]}' (#{v(@metadata["version"])}) is installed to that directory")
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

      super _("'#{@requested_module}' (#{v(@requested_version)}) requested; Invalid dependency cycle")
    end

    def multiline
      trace = []
      trace << _("You specified '#{@source.first[:name]}' (#{v(@requested_version)})")
      #TRANSLATORS Second half of "You specified a module..."
      trace += @source[1..-1].map { |m| _("which depends on '#{m[:name]}' (#{v(m[:version])})") }

      message = []
      message << _("Could not install module '#{@requested_module}' (#{v(@requested_version)})")
      message << _("  No version of '#{@module_name}' will satisfy dependencies")
      message << trace.map { |s| _("    #{s}") }.join(",\n")
      message << _("    Use `puppet module install --force` to install this module anyway")

      message.join("\n")
    end
  end

  class NotInstalledError < ModuleToolError
    def initialize(options)
      @module_name = options[:module_name]
      @suggestions = options[:suggestions] || []
      @action      = options[:action]
      super _("Could not #{@action} '#{@module_name}'; module is not installed")
    end

    def multiline
      message = []
      message << _("Could not #{@action} module '#{@module_name}'")
      message << _("  Module '#{@module_name}' is not installed")
      message += @suggestions.map do |suggestion|
        _("    You may have meant `puppet module #{@action} #{suggestion}`")
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
      super _("Could not #{@action} '#{@module_name}'; module appears in multiple places in the module path")
    end

    def multiline
      message = []
      message << _("Could not #{@action} module '#{@module_name}'")
      message << _("  Module '#{@module_name}' appears multiple places in the module path")
      message += @modules.map do |mod|
        _("    '#{@module_name}' (#{v(mod.version)}) was found in #{mod.modulepath}")
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
      super _("Could not #{@action} '#{@module_name}'; module has had changes made locally")
    end

    def multiline
      message = []
      message << _("Could not #{@action} module '#{@module_name}' (#{vstring})")
      message << _("  Installed module has had changes made locally")
      message << _("    Use `puppet module #{@action} --ignore-changes` to #{@action} this module anyway")
      message.join("\n")
    end
  end

  class InvalidModuleError < ModuleToolError
    def initialize(name, options)
      @name   = name
      @action = options[:action]
      @error  = options[:error]
      super _("Could not #{@action} '#{@name}'; #{@error.message}")
    end

    def multiline
      message = []
      message << _("Could not #{@action} module '#{@name}'")
      message << _("  Failure trying to parse metadata")
      message << _("    Original message was: #{@error.message}")
      message.join("\n")
    end
  end
end
