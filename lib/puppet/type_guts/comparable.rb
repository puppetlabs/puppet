module Puppet
  class Type
    include Comparable

    # Compares this type against the given _other_ (type) and returns -1, 0, or +1 depending on the order.
    # @param other [Object] the object to compare against (produces nil, if not kind of Type}
    # @return [-1, 0, +1, nil] produces -1 if this type is before the given _other_ type, 0 if equals, and 1 if after.
    #   Returns nil, if the given _other_ is not a kind of Type.
    # @see Comparable
    #
    def <=>(other)
      # Order is only maintained against other types, not arbitrary objects.
      # The natural order is based on the reference name used when comparing
      return nil unless other.is_a?(Puppet::CompilableResourceType) || other.class.is_a?(Puppet::CompilableResourceType)
      # against other type instances.
      self.ref <=> other.ref
    end
  end
end
