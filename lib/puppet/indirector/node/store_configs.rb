# frozen_string_literal: true

require_relative '../../../puppet/indirector/store_configs'
require_relative '../../../puppet/node'

class Puppet::Node::StoreConfigs < Puppet::Indirector::StoreConfigs
  desc 'Part of the "storeconfigs" feature. Should not be directly set by end users.'
end
