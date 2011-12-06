Puppet::Face.define(:module_tool, '1.0.0') do
  action(:build) do
    summary "Build a module release package."
    description <<-EOT
      Build a module release archive file by processing the Modulefile in the
      module directory.  The release archive file will be stored in the pkg
      directory of the module directory.
    EOT

    returns "Pathname object representing the path to the release archive."

    examples <<-EOT
      Build a module release from within the module directory:

      $ puppet module_tool build

      Build a module release from outside the module directory:

      $ puppet module_tool build /path/to/module
    EOT

    arguments "<path>"

    when_invoked do |path, options|
      root_path = Puppet::Module::Tool.find_module_root(path)
      Puppet::Module::Tool::Applications::Builder.run(root_path, options)
    end

    when_rendering :console do |return_value|
      # Get the string representation of the Pathname object and print it to
      # the console.
      return_value.to_s
    end
  end
end
