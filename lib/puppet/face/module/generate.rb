Puppet::Face.define(:module, '1.0.0') do
  action(:generate) do
    summary "Generate boilerplate for a new module."
    description <<-EOT
      Generates boilerplate for a new module by creating the directory
      structure and files recommended for the Puppet community's best practices.

      A module may need additional directories beyond this boilerplate
      if it provides plugins, files, or templates.
    EOT

    returns "Array of Pathname objects representing paths of generated files."

    examples <<-EOT
      Generate a new module in the current directory:

      $ puppet module generate puppetlabs-ssh
      notice: Generating module at /Users/kelseyhightower/puppetlabs-ssh
      puppetlabs-ssh
      puppetlabs-ssh/Modulefile
      puppetlabs-ssh/README
      puppetlabs-ssh/manifests
      puppetlabs-ssh/manifests/init.pp
      puppetlabs-ssh/spec
      puppetlabs-ssh/spec/spec_helper.rb
      puppetlabs-ssh/tests
      puppetlabs-ssh/tests/init.pp
    EOT

    arguments "<name>"

    when_invoked do |name, options|
      Puppet::ModuleTool.set_option_defaults options
      Puppet::ModuleTool::Applications::Generator.run(name, options)
    end

    when_rendering :console do |return_value|
      return_value.map {|f| f.to_s }.join("\n")
    end
  end
end
