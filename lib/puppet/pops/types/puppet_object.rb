module Puppet::Pops
module Types

# Marker module for implementations that are mapped to Object types
# @api public
module PuppetObject
  # Returns all classes that includes this module
  def self.descendants
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end

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
