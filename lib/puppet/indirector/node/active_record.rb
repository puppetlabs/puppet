require 'puppet/rails/host'
require 'puppet/indirector/active_record'
require 'puppet/node'

class Puppet::Node::ActiveRecord < Puppet::Indirector::ActiveRecord
  use_ar_model Puppet::Rails::Host

  desc "A component of ActiveRecord storeconfigs. ActiveRecord-based storeconfigs
    and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"

  def initialize
    Puppet.deprecation_warning "ActiveRecord-based storeconfigs and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"
    super
  end

  def find(request)
    node = super
    node.environment = request.environment
    node.fact_merge
    node
  end
end
