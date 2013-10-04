# Select and show a list of resources of a given type.
Puppet::Face.define(:catalog, '0.0.1') do
  action :select do
    summary "Retrieve a catalog and filter it for resources of a given type."
    arguments "<host> <resource_type>"
    returns <<-'EOT'
      A list of resource references ("Type[title]"). When used from the API,
      returns an array of Puppet::Resource objects excised from a catalog.
    EOT
    description <<-'EOT'
      Retrieves a catalog for the specified host, then searches it for all
      resources of the requested type.
    EOT
    notes <<-'NOTES'
      By default, this action will retrieve a catalog from Puppet's compiler
      subsystem; you must call the action with `--terminus rest` if you wish
      to retrieve a catalog from the puppet master.

      FORMATTING ISSUES: This action cannot currently render useful yaml;
      instead, it returns an entire catalog. Use json instead.
    NOTES
    examples <<-'EOT'
      Ask the puppet master for a list of managed file resources for a node:

      $ puppet catalog select --terminus rest somenode.magpie.lan file
    EOT
    when_invoked do |host, type, options|
      # REVISIT: Eventually, type should have a default value that triggers
      # the non-specific behaviour.  For now, though, this will do.
      # --daniel 2011-05-03
      catalog = Puppet::Resource::Catalog.indirection.find(host)

      if type == '*'
        catalog.resources
      else
        type = type.downcase
        catalog.resources.reject { |res| res.type.downcase != type }
      end
    end

    when_rendering :console do |value|
      if value.nil? then
        "no matching resources found"
      else
        value.map {|x| x.to_s }.join("\n")
      end
    end
  end
end
