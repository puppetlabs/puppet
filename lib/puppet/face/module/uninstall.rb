Puppet::Face.define(:module, '1.0.0') do
  action(:uninstall) do
    summary "Uninstall a puppet module."
    description <<-EOT
      Uninstalls a puppet module from the modulepath (or a specific
      target directory).
    EOT

    returns "Hash of module objects representing uninstalled modules and related errors."

    examples <<-EOT
      Uninstall a module from all directories in the modulepath:

      $ puppet module uninstall ssh
      Removed /etc/puppet/modules/ssh (v1.0.0)

      Uninstall a module from a specific directory:

      $ puppet module uninstall --modulepath /usr/share/puppet/modules ssh
      Removed /usr/share/puppet/modules/ssh (v1.0.0)

      Uninstall a module from a specific environment:

      $ puppet module uninstall --environment development
      Removed /etc/puppet/environments/development/modules/ssh (v1.0.0)

      Uninstall a specific version of a module:

      $ puppet module uninstall --version 2.0.0 ssh
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
      if options[:modulepath]
        unless File.directory?(options[:modulepath])
          raise ArgumentError, "Directory #{options[:modulepath]} does not exist"
        end
      end

      Puppet[:modulepath] = options[:modulepath] if options[:modulepath]
      options[:name] = name

      Puppet::Module::Tool::Applications::Uninstaller.run(name, options)
    end

    when_rendering :console do |return_value|
      output = ''

      return_value[:removed_mods].each do |mod|
        msg = "Removed #{mod.path}"
        msg << " (v#{mod.version})" if mod.version
        msg << "\n"
        output << msg
      end

      output
    end
  end
end
