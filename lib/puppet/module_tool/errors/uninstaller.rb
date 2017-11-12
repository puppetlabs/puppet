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
      module_versions_list = @modules.map do |mod|
        _("    '%{module_name}' (%{version}) is installed in %{path}") % { module_name: mod[:name], version: v(mod[:version]), path: mod[:path] }
      end.join("\n")

      _(<<-MSG).chomp  % { module_name: @module_name, version: v(@version) , module_versions_list: module_versions_list }
Could not uninstall module '%{module_name}' (%{version})
  No installed version of '%{module_name}' matches (%{version})
%{module_versions_list}
      MSG
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

      module_requirements_list = @required_by.map do |mod|
        msg_variables = { module_name: mod['name'], version: v(mod['version']), module_dependency: @module_name,
                          dependency_version: v(mod['version_requirement']) }
        _("    '%{module_name}' (%{version}) requires '%{module_dependency}' (%{dependency_version})") % msg_variables
      end.join("\n")

      if @requested_version
        msg_variables = { module_name: @module_name, requested_version: @requested_version, version: v(@installed_version),
                          module_requirements_lis: module_requirements_list }
        #TRANSLATORS `puppet module uninstall --force` is a command line option that should not be translated
        _(<<-EOF).chomp % msg_variables
Could not uninstall module '%{module_name}' (v%{requested_version})
  Other installed modules have dependencies on '%{module_name}' (%{version})
%{module_requirements_list}
    Use `puppet module uninstall --force` to uninstall this module anyway
        EOF
      else
        #TRANSLATORS `puppet module uninstall --force` is a command line option that should not be translated
        _(<<-EOF) % { module_name: @module_name, version: v(@installed_version), module_requirements_list: module_requirements_list }
Could not uninstall module '%{module_name}'
  Other installed modules have dependencies on '%{module_name}' (%{version})
%{module_requirements_list}
    Use `puppet module uninstall --force` to uninstall this module anyway
        EOF
      end
    end
  end
end
