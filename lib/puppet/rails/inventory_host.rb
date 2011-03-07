require 'puppet/rails/inventory_fact'

class Puppet::Rails::InventoryHost < ::ActiveRecord::Base
  has_many :facts, :class_name => "Puppet::Rails::InventoryFact", :dependent => :delete_all

  def facts_to_hash
    facts.inject({}) do |fact_hash,fact|
      fact_hash.merge(fact.name => fact.value)
    end
  end
end
