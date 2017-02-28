module Puppet::Pops
module Types

# Marker module for implementations that are mapped to Object types
# @api public
module PuppetObject
  # Returns the Puppet Type for this instance. The implementing class must
  # add the {#_pcore_type} as a class method.
  #
  # @return [PObjectType] the type
  def _pcore_type
    self.class._pcore_type
  end

  def _pcore_all_contents(path, &block)
  end

  def _pcore_contents
  end

  def _pcore_init_hash
    EMPTY_HASH
  end
end
end
end
