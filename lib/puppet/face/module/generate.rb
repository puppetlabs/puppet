Puppet::Face.define(:module, '1.0.0') do
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

      $ puppet module generate puppetlabs-ssh
      notice: Generating module at /Users/kelseyhightower/puppetlabs-ssh
      puppetlabs-ssh
      puppetlabs-ssh/tests
      puppetlabs-ssh/tests/init.pp
      puppetlabs-ssh/spec
      puppetlabs-ssh/spec/spec_helper.rb
      puppetlabs-ssh/spec/spec.opts
      puppetlabs-ssh/README
      puppetlabs-ssh/Modulefile
      puppetlabs-ssh/metadata.json
      puppetlabs-ssh/manifests
      puppetlabs-ssh/manifests/init.pp
    EOT

    arguments "<name>"

    when_invoked do |name, options|
      Puppet::Module::Tool::Applications::Generator.run(name, options)
    end

    when_rendering :console do |return_value|
      return_value.map {|f| f.to_s }.join("\n")
    end
  end
end
