Puppet::Face.define(:module, '1.0.0') do
  action(:build) do
    summary "Build a module release package."
    description <<-EOT
      Build a module release archive file by processing the Modulefile in the
      module directory.  The release archive file will be stored in the pkg
      directory of the module directory.
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
      Puppet::Module::Tool::Applications::Builder.run(path, options)
    end

    when_rendering :console do |return_value|
      # Get the string representation of the Pathname object.
      return_value.to_s
    end
  end
end
