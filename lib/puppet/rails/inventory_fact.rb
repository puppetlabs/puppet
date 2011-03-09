require 'puppet/rails/inventory_host'

class Puppet::Rails::InventoryFact < ::ActiveRecord::Base
  belongs_to :host, :class_name => "Puppet::Rails::InventoryHost"
  serialize :value
end
