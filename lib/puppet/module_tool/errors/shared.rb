module Puppet::ModuleTool::Errors

  class NoVersionsSatisfyError < ModuleToolError
    def initialize(options)
      @requested_name    = options[:requested_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @dependency_name   = options[:dependency_name]
      @conditions        = options[:conditions]
      @action            = options[:action]

      super "Could not #{@action} '#{@requested_name}' (#{vstring}); module '#{@dependency_name}' cannot satisfy dependencies"
    end

    attr_reader :dependency_name

    def add_conditions(conditions)
      @conditions += conditions
    end

    def multiline
      same_mod = @requested_name == @dependency_name

      message = []
      message << "Could not #{@action} module '#{@requested_name}' (#{vstring})"
      message << "  No version of '#{@dependency_name}' will satisfy dependencies"
      message << "    You specified '#{@requested_name}' (#{v(@requested_version)})" if same_mod
      message += @conditions.select { |c| c[:source] }.sort_by { |c| c[:source][:module_name] }.map do |c|
        source = c[:source]
        "    '#{source[:module_name]}' (#{v(source[:version])}) requires '#{@dependency_name}' (#{v(c[:constraint])})"
      end
      message << "    Use `puppet module #{@action} --force` to #{@action} this module anyway" if same_mod
      message << "    Use `puppet module #{@action} --ignore-dependencies` to #{@action} only this module" unless same_mod

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

      super "'#{@requested_module}' (#{v(@requested_version)}) requested; Invalid dependency cycle"
    end

    def multiline
      trace = []
      trace << "You specified '#{@source.first[:name]}' (#{v(@requested_version)})"
      trace += @source[1..-1].map { |m| "which depends on '#{m[:name]}' (#{v(m[:version])})" }

      message = []
      message << "Could not install module '#{@requested_module}' (#{v(@requested_version)})"
      message << "  No version of '#{@module_name}' will satisfy dependencies"
      message << trace.map { |s| "    #{s}" }.join(",\n")
      message << "    Use `puppet module install --force` to install this module anyway"

      message.join("\n")
    end
  end

  class NotInstalledError < ModuleToolError
    def initialize(options)
      @module_name = options[:module_name]
      @suggestions = options[:suggestions] || []
      @action      = options[:action]
      super "Could not #{@action} '#{@module_name}'; module is not installed"
    end

    def multiline
      message = []
      message << "Could not #{@action} module '#{@module_name}'"
      message << "  Module '#{@module_name}' is not installed"
      message += @suggestions.map do |suggestion|
        "    You may have meant `puppet module #{@action} #{suggestion}`"
      end
      message << "    Use `puppet module install` to install this module" if @action == :upgrade
      message.join("\n")
    end
  end

  class MultipleInstalledError < ModuleToolError
    def initialize(options)
      @module_name = options[:module_name]
      @modules     = options[:installed_modules]
      @action      = options[:action]
      super "Could not #{@action} '#{@module_name}'; module appears in multiple places in the module path"
    end

    def multiline
      message = []
      message << "Could not #{@action} module '#{@module_name}'"
      message << "  Module '#{@module_name}' appears multiple places in the module path"
      message += @modules.map do |mod|
        "    '#{@module_name}' (#{v(mod.version)}) was found in #{mod.modulepath}"
      end
      message << "    Use the `--modulepath` option to limit the search to specific directories"
      message.join("\n")
    end
  end

  class LocalChangesError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @action            = options[:action]
      super "Could not upgrade '#{@module_name}'; module is installed"
    end

    def multiline
      message = []
      message << "Could not upgrade module '#{@module_name}' (#{vstring})"
      message << "  Installed module has had changes made locally"
      message << "    Use `puppet module #{@action} --force` to upgrade this module anyway"
      message.join("\n")
    end
  end

  class MissingPackageError < InstallError
    def initialize(options)
      @requested_package = options[:requested_package]
      @action = options[:action]
      super "#{@requested_package} requested; Package #{@requested_package} does not exist"
    end

    def multiline
      message = []
      message << "Could not #{@action} from package #{@requested_package}"
      message << "  Package #{@requested_package} does not exist"
      message.join("\n")
    end
  end

  class InvalidPackageError < ModuleToolError
    def initialize(options)
      @requested_package = options[:requested_package]
      @detail = options[:detail]
      @action = options[:action]
      super "#{@requested_package} requested; Package #{@requested_package} is invalid"
    end

    def multiline
      message = []
      message << "Could not #{@action} from package #{@requested_package}"
      message << "  #{@detail}"
      message.join("\n")
    end
  end

  class NewerInstalledError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @action            = options[:action]
      super "Won't downgrade '#{@module_name}' (#{vstring})"
    end

    def multiline
      message = []
      message << "Won't downgrade module '#{@module_name}' (#{vstring})"
      message << "  Use `puppet module #{@action} --force` to force the downgrade"
      message.join("\n")
    end
  end
end
