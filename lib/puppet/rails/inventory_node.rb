require 'puppet/rails/inventory_fact'

class Puppet::Rails::InventoryNode < ::ActiveRecord::Base
  has_many :facts, :class_name => "Puppet::Rails::InventoryFact", :dependent => :delete_all

  named_scope :has_fact_with_value, lambda { |name,value|
    {
      :conditions => ["inventory_facts.name = ? AND inventory_facts.value = ?", name, value],
      :joins => :facts
    }
  }

  named_scope :has_fact_without_value, lambda { |name,value|
    {
      :conditions => ["inventory_facts.name = ? AND inventory_facts.value != ?", name, value],
      :joins => :facts
    }
  }

  named_scope :has_fact, lambda { |name|
    {
      :conditions => ["inventory_facts.name = ?", name],
      :joins => :facts
    }
  }

  def value_for(fact_name)
    fact = facts.find_by_name(fact_name)
    fact ? fact.value : nil
  end

  def facts_to_hash
    facts.inject({}) do |fact_hash,fact|
      fact_hash.merge(fact.name => fact.value)
    end
  end
end
