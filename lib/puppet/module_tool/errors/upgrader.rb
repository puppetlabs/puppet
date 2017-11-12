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
      if @newer_versions.empty?
        # TRANSLATORS `puppet module upgrade --force` is a command line option that should not be translated
        _(<<-MSG).chomp % { module_name: @module_name, version: vstring }
Could not upgrade module '%{module_name}' (%{version})
  The installed version is already the latest version matching %{version}
    Use `puppet module upgrade --force` to upgrade only this module
        MSG
      else
        if @possible_culprits.empty?
          # TRANSLATORS `puppet module upgrade --force` is a command line option that should not be translated
          _(<<-MSG).chomp % { module_name: @module_name, version: vstring, count: @newer_versions.length }
Could not upgrade module '%{module_name}' (%{version})
  There are %{count} newer versions
    No combination of dependency upgrades would satisfy all dependencies
    Use `puppet module upgrade --force` to upgrade only this module
          MSG
        else
          module_dependency_list = @possible_culprits.map {|name| "    - #{name}"}.join("\n")
          # TRANSLATORS `puppet module upgrade --force` is a command line option that should not be translated
          _(<<-MSG).chomp % { module_name: @module_name, version: vstring, count: @newer_versions.length, module_dependency_list: module_dependency_list }
Could not upgrade module '%{module_name}' (%{version})
  There are %{count} newer versions
    No combination of dependency upgrades would satisfy all dependencies
    Dependencies will not be automatically upgraded across major versions
    Upgrading one or more of these modules may permit the upgrade to succeed:
%{module_dependency_list}
    Use `puppet module upgrade --force` to upgrade only this module
          MSG
        end
      end
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
      _(<<-MSG).chomp % { action: @action, module_name: @module_name, version: vstring }
Could not %{action} module '%{module_name}' (%{version})
  Downgrading is not allowed.
      MSG
    end
  end
end
