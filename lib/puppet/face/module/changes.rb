# frozen_string_literal: true
Puppet::Face.define(:module, '1.0.0') do
  action(:changes) do
    summary _("Show modified files of an installed module.")
    description <<-EOT
      Shows any files in a module that have been modified since it was
      installed. This action compares the files on disk to the md5 checksums
      included in the module's checksums.json or, if that is missing, in
      metadata.json.
    EOT

    returns _("Array of strings representing paths of modified files.")

    examples <<-EOT
      Show modified files of an installed module:

      $ puppet module changes /etc/puppetlabs/code/modules/vcsrepo/
      warning: 1 files modified
      lib/puppet/provider/vcsrepo.rb
    EOT

    arguments _("<path>")

    when_invoked do |path, options|
      Puppet::ModuleTool.set_option_defaults options
      root_path = Puppet::ModuleTool.find_module_root(path)
      unless root_path
        raise ArgumentError, _("Could not find a valid module at %{path}") % { path: path.inspect }
      end

      Puppet::ModuleTool::Applications::Checksummer.run(root_path, options)
    end

    when_rendering :console do |return_value|
      if return_value.empty?
        Puppet.notice _("No modified files")
      else
        Puppet.warning _("%{count} files modified") % { count: return_value.size }
      end
      return_value.map do |changed_file|
        "#{changed_file}"
      end.join("\n")
    end
  end
end
