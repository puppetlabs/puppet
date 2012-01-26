Puppet::Face.define(:module, '1.0.0') do
  action(:install) do
    summary "Install a module from a repository or release archive."
    description <<-EOT
      Install a module from a release archive file on-disk or by downloading
      one from a repository. Unpack the archive into the install directory
      specified by the --dir option, which defaults to
      #{Puppet.settings[:modulepath].split(File::PATH_SEPARATOR).first}
    EOT

    returns "Pathname object representing the path to the installed module."

    examples <<-EOT
      Install a module from the default repository:

      $ puppet module install puppetlabs/vcsrepo
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /etc/puppet/modules/vcsrepo
      /etc/puppet/modules/vcsrepo

      Install a specific module version from a repository:

      $ puppet module install puppetlabs/vcsrepo -v 0.0.4
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /etc/puppet/modules/vcsrepo
      /etc/puppet/modules/vcsrepo

      Install a module into a specific directory:

      $ puppet module install puppetlabs/vcsrepo --dir=/usr/share/puppet/modules
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /usr/share/puppet/modules/vcsrepo
      /usr/share/puppet/modules/vcsrepo

      Install a module from a release archive:

      $ puppet module install puppetlabs-vcsrepo-0.0.4.tar.gz
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /etc/puppet/modules/vcsrepo
      /etc/puppet/modules/vcsrepo
    EOT

    arguments "<name>"

    option "--force", "-f" do
      summary "Force overwrite of existing module, if any."
      description <<-EOT
        Force overwrite of existing module, if any.
      EOT
    end

    option "--dir=", "-i=" do
      default_to { Puppet.settings[:modulepath].split(File::PATH_SEPARATOR).first }
      summary "The directory into which modules are installed."
      description <<-EOT
        The directory into which modules are installed, defaults to the first
        directory in the modulepath.
      EOT
    end

    option "--module-repository=", "-r=" do
      default_to { Puppet.settings[:module_repository] }
      summary "Module repository to use."
      description <<-EOT
        Module repository to use.
      EOT
    end

    option "--version=", "-v=" do
      summary "Module version to install."
      description <<-EOT
        Module version to install, can be a requirement string, eg '>= 1.0.3',
        defaults to latest version.
      EOT
    end

    when_invoked do |name, options|
      Puppet[:modulepath] = options[:modulepath] if options[:modulepath]
      Puppet[:module_repository] = options[:module_repository] if options[:module_repository]
      Puppet::Module::Tool::Applications::Installer.run(name, options)
    end

    when_rendering :console do |return_value|
      ''
    end
  end
end
