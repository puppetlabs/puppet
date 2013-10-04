require 'puppet/indirector/store_configs'
require 'puppet/node'

class Puppet::Node::StoreConfigs < Puppet::Indirector::StoreConfigs

  desc %q{Part of the "storeconfigs" feature. Should not be directly set by end users.}

end
