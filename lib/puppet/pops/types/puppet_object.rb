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
    t = self.class._pcore_type
    if t.parameterized?
      unless instance_variable_defined?(:@_cached_ptype)
        # Create a parameterized type based on the values of this instance that
        # contains a parameter value for each type parameter that matches an
        # attribute by name and type of value
        @_cached_ptype = PObjectTypeExtension.create_from_instance(t, self)
      end
      t = @_cached_ptype
    end
    t
  end

  def _pcore_all_contents(path, &block)
  end

  def _pcore_contents
  end

  def _pcore_init_hash
    {}
  end

  def to_s
    TypeFormatter.string(self)
  end
end
end
end
