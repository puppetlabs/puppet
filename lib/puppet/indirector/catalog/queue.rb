require 'puppet/resource/catalog'
require 'puppet/indirector/queue'

class Puppet::Resource::Catalog::Queue < Puppet::Indirector::Queue

  desc "Part of async storeconfigs, requiring the puppet queue daemon. ActiveRecord-based storeconfigs
    and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"

end
