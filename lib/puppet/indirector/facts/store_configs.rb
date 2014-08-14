require 'puppet/node/facts'
require 'puppet/indirector/store_configs'

class Puppet::Node::Facts::StoreConfigs < Puppet::Indirector::StoreConfigs

  desc %q{Part of the "storeconfigs" feature. Should not be directly set by end users.}

  def allow_remote_requests?
    false
  end
end
