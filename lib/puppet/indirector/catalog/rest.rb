require 'puppet/resource/catalog'
require 'puppet/indirector/rest'

class Puppet::Resource::Catalog::Rest < Puppet::Indirector::REST
    desc "Find resource catalogs over HTTP via REST."
end
