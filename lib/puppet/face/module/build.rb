Puppet::Face.define(:module, '1.0.0') do
  action(:build) do
    summary "Build a module release package."
    description <<-EOT
      Prepares a local module for release on the Puppet Forge by building a
      ready-to-upload archive file.

      This action uses the Modulefile in the module directory to set metadata
      used by the Forge. See <http://links.puppetlabs.com/modulefile> for more
      about writing modulefiles.

      After being built, the release archive file can be found in the module's
      `pkg` directory.
    EOT

    returns "Pathname object representing the path to the release archive."

    examples <<-EOT
      Build a module release:

      $ puppet module build puppetlabs-apache
      notice: Building /Users/kelseyhightower/puppetlabs-apache for release
      puppetlabs-apache/pkg/puppetlabs-apache-0.0.1.tar.gz
    EOT

    arguments "<path>"

    when_invoked do |path, options|
      Puppet::ModuleTool::Applications::Builder.run(path, options)
    end

    when_rendering :console do |return_value|
      # Get the string representation of the Pathname object.
      return_value.to_s
    end
  end
end
