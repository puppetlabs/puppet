Puppet::Face.define(:module, '1.0.0') do
  action(:uninstall) do
    summary "Uninstall a puppet module."
    description <<-EOT
      Uninstall a puppet module from the modulepath or a specific
      target directory which defaults to
      #{Puppet.settings[:modulepath].split(File::PATH_SEPARATOR).join(', ')}.
    EOT

    returns "Array of strings representing paths of uninstalled files."

    examples <<-EOT
      Uninstall a module from all directories in the modulepath:

      $ puppet module uninstall ssh
      Removed /etc/puppet/modules/ssh

      Uninstall a module from a specific directory:

      $ puppet module uninstall --target-directory /usr/share/puppet/modules ssh
      Removed /usr/share/puppet/modules/ssh
    EOT

    arguments "<name>"

    option "--target-directory=", "-t=" do
      default_to { Puppet.settings[:modulepath].split(File::PATH_SEPARATOR) }
      summary "The target directory to search from modules."
      description <<-EOT
        The target directory to search for modules.
      EOT
    end

    when_invoked do |name, options|

      if options[:target_directory].is_a?(Array)
        options[:target_directories] = options[:target_directory]
      else
        options[:target_directories] = [ options[:target_directory] ]
      end
      options.delete(:target_directory)

      Puppet::Module::Tool::Applications::Uninstaller.run(name, options)
    end

    when_rendering :console do |removed_modules|
      removed_modules.map { |path| "Removed #{path}" }.join('\n')
    end
  end
end
