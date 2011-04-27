# Select and show a list of resources of a given type.
Puppet::Face.define(:catalog, '0.0.1') do
  action :select do
    summary "Select and show a list of resources of a given type"
    description <<-EOT
Retrieves a catalog for the specified host and returns an array of
resources of the given type. This action is not intended for
command-line use.
    EOT
    notes <<-NOTES
The type name for this action must be given in its capitalized form.
That is, calling `catalog select mynode file` will return an empty
array, whereas calling it with 'File' will return a list of the node's
file resources.

By default, this action will retrieve a catalog from Puppet's compiler
subsystem; you must call the action with `--terminus rest` if you wish
to retrieve a catalog from the puppet master.
    NOTES
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
