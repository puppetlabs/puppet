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

      Install a specific module version from a repository:

      $ puppet module install puppetlabs/vcsrepo -v 0.0.4
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /etc/puppet/modules/vcsrepo

      Install a module into a specific directory:

      $ puppet module install puppetlabs/vcsrepo --dir=/usr/share/puppet/modules
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /usr/share/puppet/modules/vcsrepo

      Install a module into a specific directory and check for dependencies in other directories:

      $ puppet module install puppetlabs/vcsrepo --dir=/usr/share/puppet/modules --modulepath /etc/puppet/modules
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /usr/share/puppet/modules/vcsrepo
      Install a module from a release archive:

      $ puppet module install puppetlabs-vcsrepo-0.0.4.tar.gz
      notice: Installing puppetlabs-vcsrepo-0.0.4.tar.gz to /etc/puppet/modules/vcsrepo
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
        directory in the modulepath.  Setting just the dir option sets the modulepath
        as well.  If you want install to check for dependencies in other paths,
        also give the modulepath option.
      EOT
    end

    option "--module-repository=", "-r=" do
      default_to { Puppet.settings[:module_repository] }
      summary "Module repository to use."
      description <<-EOT
        Module repository to use.
      EOT
    end

    option "--modulepath MODULEPATH" do
      summary "Which directories to look for modules in"
      description <<-EOT
        The directory into which modules are installed, defaults to the first
        directory in the modulepath.  If the dir option is also given, it is prepended
        to the modulepath.
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
      if options[:dir]
        if options[:modulepath]
          sep = File::PATH_SEPARATOR
          Puppet.settings[:modulepath] = "#{options[:dir]}#{sep}#{options[:modulepath]}"
        else
          Puppet.settings[:modulepath] = options[:dir]
        end
      elsif options[:modulepath]
        Puppet.settings[:modulepath] = options[:modulepath]
      end

      Puppet.settings[:module_repository] = options[:module_repository] if options[:module_repository]
      Puppet::Module::Tool::Applications::Installer.run(name, options)
    end

    when_rendering :console do |return_value|
      ''
    end
  end
end
