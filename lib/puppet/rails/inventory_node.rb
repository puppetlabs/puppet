require 'puppet/rails/inventory_fact'

class Puppet::Rails::InventoryNode < ::ActiveRecord::Base
  has_many :facts, :class_name => "Puppet::Rails::InventoryFact", :foreign_key => :node_id, :dependent => :delete_all

  if Puppet::Util.activerecord_version < 3.0
    # For backward compatibility, add the newer name to older implementations.
    ActiveRecord::NamedScope::ClassMethods.module_eval { alias :scope :named_scope }
  end

  scope :has_fact_with_value, lambda { |name,value|
    {
      :conditions => ["inventory_facts.name = ? AND inventory_facts.value = ?", name, value.to_s],
      :joins => :facts
    }
  }

  scope :has_fact_without_value, lambda { |name,value|
    {
      :conditions => ["inventory_facts.name = ? AND inventory_facts.value != ?", name, value.to_s],
      :joins => :facts
    }
  }

  def facts_to_hash
    facts.inject({}) do |fact_hash,fact|
      fact_hash.merge(fact.name => fact.value)
    end
  end
end
