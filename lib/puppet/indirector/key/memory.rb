require 'puppet/ssl/key'
require 'puppet/indirector/memory'

class Puppet::SSL::Key::Memory < Puppet::Indirector::Memory
  desc "Store keys in memory. This is used for testing puppet."
end
