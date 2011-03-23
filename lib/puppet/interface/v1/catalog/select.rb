# Select and show a list of resources of a given type.
Puppet::Interface.interface(:catalog, 1) do
  action :select do
    invoke do |host,type|
      catalog = Puppet::Resource::Catalog.indirection.find(host)

      catalog.resources.reject { |res| res.type != type }.each { |res| puts res }
    end
  end
end
