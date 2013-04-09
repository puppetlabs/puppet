module Puppet::ModuleTool::Errors

  class UpgradeError < ModuleToolError
    def initialize(msg)
      @action = :upgrade
      super
    end
  end

  class VersionAlreadyInstalledError < UpgradeError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @specified_version = options[:specified_version]
      @dependency_name   = options[:dependency_name]
      @conditions        = options[:conditions]
      super "Could not upgrade '#{@module_name}'; a better release is already installed"
    end

    def multiline
      message = []
      message << "Could not upgrade module '#{@module_name}' (#{vstring})"
      if @conditions.empty? && !@specified_version
        message << "  The installed version is already the latest version"
      else
        message << "  The installed version is already the best fit for the current dependencies"
        message << "    You specified '#{@module_name}' (#{v(@specified_version)})" if @specified_version
        message += @conditions.sort_by { |c| c[:source][:module_name] }.map do |c|
           source = c[:source]
           "    '#{source[:module_name]}' (#{v(source[:version])}) requires '#{@module_name}' (#{v(c[:constraint])})"
        end
      end
      message << "    Use `puppet module install --force` to re-install this module"
      message.join("\n")
    end
  end

  class UnknownModuleError < UpgradeError
    def initialize(options)
      @module_name       = options[:module_name]
      @installed_version = options[:installed_version]
      @requested_version = options[:requested_version]
      @repository        = options[:repository]
      super "Could not upgrade '#{@module_name}'; module is unknown to #{@repository}"
    end

    def multiline
      message = []
      message << "Could not upgrade module '#{@module_name}' (#{vstring})"
      message << "  Module '#{@module_name}' does not exist on #{@repository}"
      message.join("\n")
    end
  end

  class UnknownVersionError < UpgradeError
    def initialize(options)
      @module_name       = options[:module_name]
      @installed_version = options[:installed_version]
      @requested_version = options[:requested_version]
      @repository        = options[:repository]
      super "Could not upgrade '#{@module_name}' (#{vstring}); module has no versions #{ @requested_version && "matching #{v(@requested_version)} "}published on #{@repository}"
    end

    def multiline
      message = []
      message << "Could not upgrade module '#{@module_name}' (#{vstring})"
      message << "  No version matching '#{@requested_version || ">= 0.0.0"}' exists on #{@repository}"
      message.join("\n")
    end
  end
end
