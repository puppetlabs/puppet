module Puppet::ModuleTool::Errors

  class UpgradeError < ModuleToolError
    def initialize(msg)
      @action = :upgrade
      super
    end
  end

  class VersionAlreadyInstalledError < UpgradeError
    attr_reader :newer_versions

    def initialize(options)
      @module_name       = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @dependency_name   = options[:dependency_name]
      @newer_versions    = options[:newer_versions]
      @possible_culprits = options[:possible_culprits]
      super _("Could not upgrade '%{module_name}'; more recent versions not found") % { module_name: @module_name }
    end

    def multiline
      message = []
      message << _("Could not upgrade module '%{module_name}' (%{version})") % { module_name: @module_name, version: vstring }
      if @newer_versions.empty?
        message << _("  The installed version is already the latest version matching %{version}") % { version: vstring }
      else
        message << _("  There are %{count} newer versions") % { count: @newer_versions.length }
        message << _("    No combination of dependency upgrades would satisfy all dependencies")
        unless @possible_culprits.empty?
          message << _("    Dependencies will not be automatically upgraded across major versions")
          message << _("    Upgrading one or more of these modules may permit the upgrade to succeed:")
          @possible_culprits.each do |name|
            message << "    - #{name}"
          end
        end
      end
      #TRANSLATORS `puppet module upgrade --force` is a command line option that should not be translated
      message << _("    Use `puppet module upgrade --force` to upgrade only this module")
      message.join("\n")
    end
  end

  class DowngradingUnsupportedError < UpgradeError
    def initialize(options)
      @module_name    = options[:module_name]
      @requested_version = options[:requested_version]
      @installed_version = options[:installed_version]
      @conditions        = options[:conditions]
      @action            = options[:action]

      super _("Could not %{action} '%{module_name}' (%{version}); downgrades are not allowed") % { action: @action, module_name: @module_name, version: vstring }
    end

    def multiline
      message = []
      message << _("Could not %{action} module '%{module_name}' (%{version})") % { action: @action, module_name: @module_name, version: vstring }
      message << _("  Downgrading is not allowed.")
      message.join("\n")
    end
  end
end
