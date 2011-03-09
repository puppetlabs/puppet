require 'puppet/rails/inventory_node'

class Puppet::Rails::InventoryFact < ::ActiveRecord::Base
  belongs_to :node, :class_name => "Puppet::Rails::InventoryNode"
end
