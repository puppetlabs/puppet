Puppet::Face.define(:module, '1.0.0') do
  action(:changes) do
    summary "Show modified files of an installed module."
    description <<-EOT
      Show files that have been modified after installation of a given module
      by comparing the on-disk md5 checksum of each file against the module's
      metadata.
    EOT

    returns "Array of strings representing paths of modified files."

    examples <<-EOT
      Show modified files of an installed module:

      $ puppet module changes /etc/puppet/modules/vcsrepo/
      warning: 1 files modified
      lib/puppet/provider/vcsrepo.rb
    EOT

    arguments "<path>"

    when_invoked do |path, options|
      root_path = Puppet::Module::Tool.find_module_root(path)
      Puppet::Module::Tool::Applications::Checksummer.run(root_path, options)
    end

    when_rendering :console do |return_value|
      if return_value.empty?
        Puppet.notice "No modified files"
      else
        Puppet.warning "#{return_value.size} files modified"
      end
      return_value.map do |changed_file|
        "#{changed_file}"
      end.join("\n")
    end
  end
end
