module Puppet::ModuleTool::Errors

  class UninstallError < ModuleToolError; end

  class NoVersionMatchesError < UninstallError
    def initialize(options)
      @module_name = options[:module_name]
      @modules     = options[:installed_modules]
      @version     = options[:version_range]
      super _("Could not uninstall '%{module_name}'; no installed version matches") % { module_name: @module_name }
    end

    def multiline
      message = []
      message << _("Could not uninstall module '%{module_name}' (%{version})") % { module_name: @module_name, version: v(@version) }
      message << _("  No installed version of '%{module_name}' matches (%{version})") % { module_name: @module_name, version: v(@version) }
      message += @modules.map do |mod|
        _("    '%{module_name}' (%{version}) is installed in %{path}") % { module_name: mod[:name], version: v(mod[:version]), path: mod[:path] }
      end
      message.join("\n")
    end
  end

  class ModuleIsRequiredError < UninstallError
    def initialize(options)
      @module_name       = options[:module_name]
      @required_by       = options[:required_by]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]

      super _("Could not uninstall '%{module_name}'; installed modules still depend upon it") % { module_name: @module_name }
    end

    def multiline
      message = []
      if @requested_version
        message << _("Could not uninstall module '%{module_name}' (v%{requested_version})") % { module_name: @module_name, requested_version: @requested_version }
      else
        message << _("Could not uninstall module '%{module_name}'") % { module_name: @module_name }
      end
      message << _("  Other installed modules have dependencies on '%{module_name}' (%{version})") % { module_name: @module_name, version: v(@installed_version) }
      message += @required_by.map do |mod|
        _("    '%{module_name}' (%{version}) requires '%{module_dep}' (%{dep_version})") % { module_name: mod['name'], version: v(mod['version']), module_dep: @module_name, dep_version: v(mod['version_requirement']) }
      end
      #TRANSLATORS `puppet module uninstall --force` is a command line option that should not be translated
      message << _("    Use `puppet module uninstall --force` to uninstall this module anyway")
      message.join("\n")
    end
  end
end
