Puppet::Face.define(:module, '1.0.0') do
  action(:uninstall) do
    summary _("Uninstall a puppet module.")
    description <<-EOT
      Uninstalls a puppet module from the modulepath (or a specific
      target directory).
      Note: Module uninstall uses MD5 checksums, which are prohibited on FIPS enabled systems.
    EOT

    returns _("Hash of module objects representing uninstalled modules and related errors.")

    examples <<-'EOT'
      Uninstall a module:

      $ puppet module uninstall puppetlabs-ssh
      Removed /etc/puppetlabs/code/modules/ssh (v1.0.0)

      Uninstall a module from a specific directory:

      $ puppet module uninstall puppetlabs-ssh --modulepath /opt/puppetlabs/puppet/modules
      Removed /opt/puppetlabs/puppet/modules/ssh (v1.0.0)

      Uninstall a module from a specific environment:

      $ puppet module uninstall puppetlabs-ssh --environment development
      Removed /etc/puppetlabs/code/environments/development/modules/ssh (v1.0.0)

      Uninstall a specific version of a module:

      $ puppet module uninstall puppetlabs-ssh --version 2.0.0
      Removed /etc/puppetlabs/code/modules/ssh (v2.0.0)
    EOT

    arguments _("<name>")

    option "--force", "-f" do
      summary _("Force uninstall of an installed module.")
      description <<-EOT
        Force the uninstall of an installed module even if there are local
        changes or the possibility of causing broken dependencies.
      EOT
    end

    option "--ignore-changes", "-c" do
      summary _("Ignore any local changes made. (Implied by --force.)")
      description <<-EOT
        Uninstall an installed module even if there are local changes to it.  (Implied by --force.)
      EOT
    end

    option "--version=" do
      summary _("The version of the module to uninstall")
      description <<-EOT
        The version of the module to uninstall. When using this option, a module
        matching the specified version must be installed or else an error is raised.
      EOT
    end

    when_invoked do |name, options|
      name = name.gsub('/', '-')

      Puppet::ModuleTool.set_option_defaults options
      message = if options[:version]
                  module_version = colorize(:cyan, options[:version].sub(/^(?=\d)/, 'v'))
                  _("Preparing to uninstall '%{name}' (%{module_version}) ...") % { name: name, module_version: module_version }
                else
                  _("Preparing to uninstall '%{name}' ...") % { name: name }
                end
      Puppet.notice message
      Puppet::ModuleTool::Applications::Uninstaller.run(name, options)
    end

    when_rendering :console do |return_value|
      if return_value[:result] == :failure
        Puppet.err(return_value[:error][:multiline])
        exit 1
      else
        mod = return_value[:affected_modules].first
        message = if mod.version
                    module_version = colorize(:cyan, mod.version.to_s.sub(/^(?=\d)/, 'v'))
                    _("Removed '%{name}' (%{module_version}) from %{path}") % { name: return_value[:module_name], module_version: module_version, path: mod.modulepath }
                  else
                    _("Removed '%{name}' from %{path}") % { name: return_value[:module_name], path: mod.modulepath }
                  end
        message
      end
    end
  end
end
