Puppet::Face.define(:module_tool, '0.0.1') do
  action(:clean) do
    summary "Clean the module download cache."
    description <<-EOT
      Clean the module download cache.
    EOT

    returns "Return a status Hash"

    examples <<-EOT
      Clean the module download cache:

      $ puppet module_tool clean
    EOT

    when_invoked do |options|
      Puppet::Module::Tool::Applications::Cleaner.run(options)
    end

    when_rendering :console do |return_value|
      # Print the status message to the console.
      return_value[:msg]
    end
  end
end
