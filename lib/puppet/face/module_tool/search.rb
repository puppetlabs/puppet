Puppet::Face.define(:module_tool, '1.0.0') do
  action(:search) do
    summary "Search a repository for a module."
    description <<-EOT
      Search a repository for modules whose names match a specific substring.
    EOT

    returns "Array of module metadata hashes"

    examples <<-EOT
      Search the default repository for a module:

      $ puppet module_tool search modulename
    EOT

    arguments "<term>"

    option "--module-repository=", "-r=" do
      default_to { Puppet.settings[:module_repository] }
      summary "Module repository to use."
      description <<-EOT
        Module repository to use.
      EOT
    end

    when_invoked do |term, options|
      Puppet.notice "Searching #{options[:module_repository]}"
      Puppet::Module::Tool::Applications::Searcher.run(term, options)
    end

    when_rendering :console do |return_value|
      Puppet.notice "#{return_value.size} found."
      return_value.map do |match|
        "#{match['full_name']} (#{match['version']})"
      end.join("\n")
    end
  end
end
