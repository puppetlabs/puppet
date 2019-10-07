# encoding: UTF-8
require 'puppet/forge'
require 'puppet/module_tool/install_directory'
require 'pathname'

Puppet::Face.define(:module, '1.0.0') do
  action(:install) do
    summary _("Install a module from the Puppet Forge or a release archive.")
    description <<-EOT
      Installs a module from the Puppet Forge or from a release archive file.
      Note: Module install uses MD5 checksums, which are prohibited on FIPS enabled systems.

      The specified module will be installed into the directory
      specified with the `--target-dir` option, which defaults to the first
      directory in the modulepath.
    EOT

    returns _("Pathname object representing the path to the installed module.")

    examples <<-'EOT'
      Install a module:

      $ puppet module install puppetlabs-vcsrepo
      Preparing to install into /etc/puppetlabs/code/modules ...
      Downloading from https://forgeapi.puppet.com ...
      Installing -- do not interrupt ...
      /etc/puppetlabs/code/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module to a specific environment:

      $ puppet module install puppetlabs-vcsrepo --environment development
      Preparing to install into /etc/puppetlabs/code/environments/development/modules ...
      Downloading from https://forgeapi.puppet.com ...
      Installing -- do not interrupt ...
      /etc/puppetlabs/code/environments/development/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a specific module version:

      $ puppet module install puppetlabs-vcsrepo -v 0.0.4
      Preparing to install into /etc/puppetlabs/modules ...
      Downloading from https://forgeapi.puppet.com ...
      Installing -- do not interrupt ...
      /etc/puppetlabs/code/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module into a specific directory:

      $ puppet module install puppetlabs-vcsrepo --target-dir=/opt/puppetlabs/puppet/modules
      Preparing to install into /opt/puppetlabs/puppet/modules ...
      Downloading from https://forgeapi.puppet.com ...
      Installing -- do not interrupt ...
      /opt/puppetlabs/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module into a specific directory and check for dependencies in other directories:

      $ puppet module install puppetlabs-vcsrepo --target-dir=/opt/puppetlabs/puppet/modules --modulepath /etc/puppetlabs/code/modules
      Preparing to install into /opt/puppetlabs/puppet/modules ...
      Downloading from https://forgeapi.puppet.com ...
      Installing -- do not interrupt ...
      /opt/puppetlabs/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module from a release archive:

      $ puppet module install puppetlabs-vcsrepo-0.0.4.tar.gz
      Preparing to install into /etc/puppetlabs/code/modules ...
      Downloading from https://forgeapi.puppet.com ...
      Installing -- do not interrupt ...
      /etc/puppetlabs/code/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module from a release archive and ignore dependencies:

      $ puppet module install puppetlabs-vcsrepo-0.0.4.tar.gz --ignore-dependencies
      Preparing to install into /etc/puppetlabs/code/modules ...
      Installing -- do not interrupt ...
      /etc/puppetlabs/code/modules
      └── puppetlabs-vcsrepo (v0.0.4)

    EOT

    arguments _("<name>")

    option "--force", "-f" do
      summary _("Force overwrite of existing module, if any. (Implies --ignore-dependencies.)")
      description <<-EOT
        Force overwrite of existing module, if any.
        Implies --ignore-dependencies.
      EOT
    end

    option "--target-dir DIR", "-i DIR" do
      summary _("The directory into which modules are installed.")
      description <<-EOT
        The directory into which modules are installed; defaults to the first
        directory in the modulepath.

        Specifying this option will change the installation directory, and
        will use the existing modulepath when checking for dependencies. If
        you wish to check a different set of directories for dependencies, you
        must also use the `--environment` or `--modulepath` options.
      EOT
    end

    option "--ignore-dependencies" do
      summary _("Do not attempt to install dependencies. (Implied by --force.)")
      description <<-EOT
        Do not attempt to install dependencies. Implied by --force.
      EOT
    end

    option "--version VER", "-v VER" do
      summary _("Module version to install.")
      description <<-EOT
        Module version to install; can be an exact version or a requirement string,
        eg '>= 1.0.3'. Defaults to latest version.
      EOT
    end

    when_invoked do |name, options|
      Puppet::ModuleTool.set_option_defaults options
      Puppet.notice _("Preparing to install into %{dir} ...") % { dir: options[:target_dir] }

      install_dir = Puppet::ModuleTool::InstallDirectory.new(Pathname.new(options[:target_dir]))
      Puppet::ModuleTool::Applications::Installer.run(name, install_dir, options)
    end

    when_rendering :console do |return_value, name, options|
      if return_value[:result] == :noop
        Puppet.notice _("Module %{name} %{version} is already installed.") % { name: name, version: return_value[:version] }
        exit 0
      elsif return_value[:result] == :failure
        Puppet.err(return_value[:error][:multiline])
        exit 1
      else
        tree = Puppet::ModuleTool.build_tree(return_value[:graph], return_value[:install_dir])

        "#{return_value[:install_dir]}\n" +
        Puppet::ModuleTool.format_tree(tree)
      end
    end
  end
end
