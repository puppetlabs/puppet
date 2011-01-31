# Select and show a list of resources of a given type.
Puppet::Interface::Catalog.action :select do |*args|
  puts "Selecting #{args.inspect}"
end
