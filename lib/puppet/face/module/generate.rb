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

    option "--without-default-skeleton" do
      summary "Skip default skeleton? Requires a custom skeleton through --with-custom-skeleton"
      description "This enables you to skip the default skeleton files for your module."
    end

    option "--with-custom-skeleton" do
      summary "Use custom skeleton from #{Puppet.settings[:module_working_dir]}/skeleton."
      description "If true, files and directories from #{Puppet.settings[:module_working_dir]}/skeleton are taken to generate the base module directory. Files from the default skeleton will be overridden."
    end

    when_invoked do |name, options|
      Puppet::ModuleTool.set_option_defaults options
      Puppet::ModuleTool::Applications::Generator.run(name, options)
    end

    when_rendering :console do |return_value|
      return_value.map {|f| f.to_s }.join("\n")
    end
  end
end
