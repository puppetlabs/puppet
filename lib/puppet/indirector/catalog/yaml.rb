require 'puppet/resource/catalog'
require 'puppet/indirector/yaml'

class Puppet::Resource::Catalog::Yaml < Puppet::Indirector::Yaml
  desc "Store catalogs as flat files, serialized using YAML."
end
