# frozen_string_literal: true

require_relative '../../../puppet/indirector/store_configs'
require_relative '../../../puppet/resource/catalog'

class Puppet::Resource::Catalog::StoreConfigs < Puppet::Indirector::StoreConfigs
  desc %q(Part of the "storeconfigs" feature. Should not be directly set by end users.)
end
