# Select and show a list of resources of a given type.
Puppet::Face.define(:catalog, '0.0.1') do
  action :select do
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
