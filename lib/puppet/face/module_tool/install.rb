Puppet::Face.define(:module_tool, '1.0.0') do
  action(:install) do
    summary "Install a module from a repository or release archive."
    description <<-EOT
      Install a module from a release archive file on-disk or by downloading
      one from a repository. Unpack the archive into the install directory
      specified by the --install-dir option, which defaults to the first
      directory in the modulepath.
    EOT

    returns "Pathname object representing the path to the installed module."

    examples <<-EOT
      Install a module from the default repository:

      $ puppet module_tool install username-modulename

      Install a specific module version from a repository:

      $ puppet module_tool install username-modulename --version=0.0.1

      Install a module into a specific directory:

      $ puppet module_tool install username-modulename --install-dir=path

      Install a module from a release archive:

      $ puppet module_tool install username-modulename-0.0.1.tar.gz
    EOT

    arguments "<name>"

    option "--force", "-f" do
      summary "Force overwrite of existing module, if any."
      description <<-EOT
        Force overwrite of existing module, if any.
      EOT
    end

    option "--install-dir=", "-i=" do
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
      Puppet::Module::Tool::Applications::Installer.run(name, options)
    end

    when_rendering :console do |return_value|
      # Get the string representation of the Pathname object and print it to
      # the console.
      return_value.to_s
    end
  end
end
