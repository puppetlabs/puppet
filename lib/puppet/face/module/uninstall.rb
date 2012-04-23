Puppet::Face.define(:module, '1.0.0') do
  action(:uninstall) do
    summary "Uninstall a puppet module."
    description <<-EOT
      Uninstalls a puppet module from the modulepath (or a specific
      target directory).
    EOT

    returns "Hash of module objects representing uninstalled modules and related errors."

    examples <<-EOT
      Uninstall a module:

      $ puppet module uninstall puppetlabs-ssh
      Removed /etc/puppet/modules/ssh (v1.0.0)

      Uninstall a module from a specific directory:

      $ puppet module uninstall puppetlabs-ssh --modulepath /usr/share/puppet/modules
      Removed /usr/share/puppet/modules/ssh (v1.0.0)

      Uninstall a module from a specific environment:

      $ puppet module uninstall puppetlabs-ssh --environment development
      Removed /etc/puppet/environments/development/modules/ssh (v1.0.0)

      Uninstall a specific version of a module:

      $ puppet module uninstall puppetlabs-ssh --version 2.0.0
      Removed /etc/puppet/modules/ssh (v2.0.0)
    EOT

    arguments "<name>"

    option "--force", "-f" do
      summary "Force uninstall of an installed module."
      description <<-EOT
        Force the uninstall of an installed module even if there are local
        changes or the possibility of causing broken dependencies.
      EOT
    end

    option "--environment NAME" do
      default_to { "production" }
      summary "The target environment to uninstall modules from."
      description <<-EOT
        The target environment to uninstall modules from.
      EOT
    end

    option "--version=" do
      summary "The version of the module to uninstall"
      description <<-EOT
        The version of the module to uninstall. When using this option, a module
        matching the specified version must be installed or else an error is raised.
      EOT
    end

    option "--modulepath=" do
      summary "The target directory to search for modules."
      description <<-EOT
        The target directory to search for modules.
      EOT
    end

    when_invoked do |name, options|
      Puppet[:modulepath] = options[:modulepath] if options[:modulepath]
      name = name.gsub('/', '-')

      Puppet.notice "Preparing to uninstall '#{name}'" << (options[:version] ? " (#{colorize(:cyan, options[:version].sub(/^(?=\d)/, 'v'))})" : '') << " ..."
      Puppet::ModuleTool::Applications::Uninstaller.run(name, options)
    end

    when_rendering :console do |return_value|
      if return_value[:result] == :failure
        Puppet.err(return_value[:error][:multiline])
        exit 1
      else
        mod = return_value[:affected_modules].first
        "Removed '#{return_value[:module_name]}'" <<
        (mod.version ? " (#{colorize(:cyan, mod.version.to_s.sub(/^(?=\d)/, 'v'))})" : '') <<
        " from #{mod.modulepath}"
      end
    end
  end
end
