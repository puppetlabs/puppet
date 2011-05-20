require 'puppet/node'
require 'puppet/indirector'

class Puppet::Node::Inventory
  extend Puppet::Indirector
  indirects :inventory, :terminus_setting => :inventory_terminus
end
