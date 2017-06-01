# The Enumeration class provides default Enumerable::Enumerator creation for Puppet Programming Language
# runtime objects that supports the concept of enumeration.
#
module Puppet::Pops::Types
  class Enumeration
    def self.enumerator(o)
      Puppet.deprecation_warning(_('Enumeration.enumerator is deprecated. Use Iterable.on instead'))
      Iterable.on(o)
    end

    def enumerator(o)
      Puppet.deprecation_warning(_('Enumeration.enumerator is deprecated. Use Iterable.on instead'))
      Iterable.on(o)
    end
  end
end
