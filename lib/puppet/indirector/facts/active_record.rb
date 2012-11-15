require 'puppet/rails/fact_name'
require 'puppet/rails/fact_value'
require 'puppet/rails/host'
require 'puppet/indirector/active_record'

class Puppet::Node::Facts::ActiveRecord < Puppet::Indirector::ActiveRecord
  use_ar_model Puppet::Rails::Host

  desc "A component of ActiveRecord storeconfigs and inventory. ActiveRecord-based storeconfigs
    and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"

  def initialize
    Puppet.deprecation_warning "ActiveRecord-based storeconfigs and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"
    super
  end

  # Find the Rails host and pull its facts as a Facts instance.
  def find(request)
    return nil unless host = ar_model.find_by_name(request.key, :include => {:fact_values => :fact_name})

    facts = Puppet::Node::Facts.new(host.name)
    facts.values = host.get_facts_hash.inject({}) do |hash, ary|
      # Convert all single-member arrays into plain values.
      param = ary[0]
      values = ary[1].collect { |v| v.value }
      values = values[0] if values.length == 1
      hash[param] = values
      hash
    end

    facts
  end

  # Save the values from a Facts instance as the facts on a Rails Host instance.
  def save(request)
    facts = request.instance

    host = ar_model.find_by_name(facts.name) || ar_model.create(:name => facts.name)

    host.merge_facts(facts.values)

    host.save
  end
end
