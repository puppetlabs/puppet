Puppet::Face.define(:module, '1.0.0') do
  action(:clean) do
    summary "Clean the module download cache."
    description <<-EOT
      Clean the module download cache.
    EOT

    returns <<-EOT
      Return a status Hash:

        { :status => "success", :msg => "Cleaned module cache." }
    EOT

    examples <<-EOT
      Clean the module download cache:

      $ puppet module clean
      Cleaned module cache.
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
