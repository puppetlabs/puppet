module Puppet::Pops
module Types

# Marker module for implementations that are mapped to Object types
# @api public
module PuppetObject
  # Returns the Puppet Type for this instance. The implementing class must
  # add the {#_ptype} as a class method.
  #
  # @return [PObjectType] the type
  def _ptype
    self.class._ptype
  end
end
end
end
