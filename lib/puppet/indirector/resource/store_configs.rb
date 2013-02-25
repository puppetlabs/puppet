require 'puppet/indirector/store_configs'
require 'puppet/indirector/resource/validator'

class Puppet::Resource::StoreConfigs < Puppet::Indirector::StoreConfigs
  include Puppet::Resource::Validator
end
