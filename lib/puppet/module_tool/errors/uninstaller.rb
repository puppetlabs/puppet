module Puppet::ModuleTool::Errors

  class UninstallError < ModuleToolError; end

  class NoVersionMatchesError < UninstallError
    def initialize(options)
      @module_name = options[:module_name]
      @modules     = options[:installed_modules]
      @version     = options[:version_range]
      super "Could not uninstall '#{@module_name}'; no installed version matches"
    end

    def multiline
      message = []
      message << "Could not uninstall module '#{@module_name}' (#{v(@version)})"
      message << "  No installed version of '#{@module_name}' matches (#{v(@version)})"
      message += @modules.map do |mod|
        "    '#{mod[:name]}' (#{v(mod[:version])}) is installed in #{mod[:path]}"
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

      super "Could not uninstall '#{@module_name}'; installed modules still depend upon it"
    end

    def multiline
      message = []
      message << ("Could not uninstall module '#{@module_name}'" << (@requested_version ? " (#{v(@requested_version)})" : ''))
      message << "  Other installed modules have dependencies on '#{@module_name}' (#{v(@installed_version)})"
      message += @required_by.map do |mod|
        "    '#{mod['name']}' (#{v(mod['version'])}) requires '#{@module_name}' (#{v(mod['version_requirement'])})"
      end
      message << "    Use `puppet module uninstall --force` to uninstall this module anyway"
      message.join("\n")
    end
  end
end
