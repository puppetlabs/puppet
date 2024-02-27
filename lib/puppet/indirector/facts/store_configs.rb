# frozen_string_literal: true

require_relative '../../../puppet/node/facts'
require_relative '../../../puppet/indirector/store_configs'

class Puppet::Node::Facts::StoreConfigs < Puppet::Indirector::StoreConfigs
  desc %q(Part of the "storeconfigs" feature. Should not be directly set by end users.)

  def allow_remote_requests?
    false
  end
end
