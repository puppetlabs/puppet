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

  def _pall_contents(path, &block)
  end

  def _pcontents
  end

  def i12n_hash
    EMPTY_HASH
  end
end
end
end
