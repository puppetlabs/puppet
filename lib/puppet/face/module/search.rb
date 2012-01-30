Puppet::Face.define(:module, '1.0.0') do
  action(:search) do
    summary "Search a repository for a module."
    description <<-EOT
      Search a repository for modules whose names match a specific substring.
    EOT

    returns "Array of module metadata hashes"

    examples <<-EOT
      Search the default repository for a module:

      $ puppet module search puppetlabs
      NAME          DESCRIPTION                          AUTHOR             KEYWORDS
      bacula        This is a generic Apache module      @puppetlabs        backups
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
      Puppet::Module::Tool::Applications::Searcher.run(term, options)
    end

    when_rendering :console do |return_value|

      FORMAT = "%-10s    %-32s     %-14s     %s\n"

      def header
        FORMAT % ['NAME', 'DESCRIPTION', 'AUTHOR', 'KEYWORDS']
      end

      def format_row(name, description, author, tag_list)
        keywords = tag_list.join(' ')
        FORMAT % [name[0..10], description[0..32], "@#{author[0..14]}", keywords]
      end

      output = ''
      output << header unless return_value.empty?

      return_value.map do |match|
        output << format_row(match['name'], match['desc'], match['author'], match['tag_list'])
      end

      output
    end
  end
end
