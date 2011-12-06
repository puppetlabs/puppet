Puppet::Face.define(:module_tool, '1.0.0') do
  action(:generate) do
    summary "Generate boilerplate for a new module."
    description <<-EOT
      Generate boilerplate for a new module by creating a directory
      pre-populated with a directory structure and files recommended for
      Puppet best practices.
    EOT

    returns "Array of Pathname objects representing paths of generated files."

    examples <<-EOT
      Generate a new module in the current directory:

      $ puppet module_tool generate username-modulename
    EOT

    arguments "<name>"

    when_invoked do |name, options|
      Puppet::Module::Tool::Applications::Generator.run(name, options)
    end

    when_rendering :console do |return_value|
      return_value.map do |generated_file|
        "#{generated_file}"
      end.join("\n")
    end
  end
end
