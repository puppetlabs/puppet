require 'puppet/indirector/store_configs'
require 'puppet/indirector/resource/validator'

class Puppet::Resource::StoreConfigs < Puppet::Indirector::StoreConfigs
  include Puppet::Resource::Validator

  desc %q{Part of the "storeconfigs" feature. Should not be directly set by end users.}

  def allow_remote_requests?
    Puppet.deprecation_warning("Accessing resources on the network is deprecated. See http://links.puppetlabs.com/deprecate-networked-resource")
    super
  end
end
