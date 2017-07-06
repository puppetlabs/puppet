require 'puppet/resource/catalog'
require 'puppet/indirector/json'

class Puppet::Resource::Catalog::Json < Puppet::Indirector::JSON
  desc "Store catalogs as flat files, serialized using JSON."
end
