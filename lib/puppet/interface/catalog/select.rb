# Select and show a list of resources of a given type.
Puppet::Interface::Catalog.action :select do
  invoke do |*args|
    host = args.shift
    type = args.shift
    catalog = Puppet::Resource::Catalog.indirection.find(host)

    catalog.resources.reject { |res| res.type != type }.each { |res| puts res }
  end
end
